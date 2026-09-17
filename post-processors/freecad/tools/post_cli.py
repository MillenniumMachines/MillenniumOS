#!/usr/bin/env python3
"""Post a CAM job to G-code from the command line, without opening the FreeCAD GUI.

Re-execs itself under FreeCAD's console binary, so run it with plain python3:

    ./post_cli.py --list job.FCStd
    ./post_cli.py job.FCStd -m "Milo V1.6 beta (MOS)" -o out.gcode
    ./post_cli.py job.FCStd -M ../machines/Milo_V1.6.fcm -o out.gcode

`-M/--machine-file` loads a .fcm straight off disk and bypasses the installed
CAM assets entirely, so a test run exercises the working tree rather than
whatever happens to be synced into the asset directory. Combined with
`--post-dir` (which defaults to this repo's post directory) a run touches no
installed copy of either half of the post.

Set FREECADCMD to pick a specific binary; otherwise the newest weekly AppImage
in ~/Downloads is preferred, falling back to freecadcmd on PATH.
"""

import argparse
import glob
import os
import sys

REPO_POST_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# --------------------------------------------------------------------------
# Stage 2: running inside FreeCAD.
# --------------------------------------------------------------------------
def run_inside_freecad():
    import FreeCAD
    import Path
    import Path.Preferences
    from Path.Post.Processor import PostProcessorFactory
    from Machine.models.machine import Machine, MachineFactory

    src = os.environ["MOS_SRC"]
    post_dir = os.environ.get("MOS_POST_DIR", "")
    machine_name = os.environ.get("MOS_MACHINE", "")
    machine_file = os.environ.get("MOS_MACHINE_FILE", "")
    legacy_post = os.environ.get("MOS_LEGACY_POST", "")
    job_names = [j for j in os.environ.get("MOS_JOBS", "").split("\n") if j]
    out = os.environ.get("MOS_OUT", "")
    do_list = os.environ.get("MOS_LIST") == "1"

    if post_dir:
        # searchPathsPost() puts the user Macro dir ahead of everything else, so
        # an installed copy would shadow the working tree. Prepend instead.
        _orig = Path.Preferences.searchPathsPost
        Path.Preferences.searchPathsPost = lambda: [post_dir] + _orig()

    doc = FreeCAD.openDocument(src, True)
    jobs = [o for o in doc.Objects if type(getattr(o, "Proxy", None)).__name__ == "ObjectJob"]

    if do_list:
        print(f"Document: {doc.Name}  ({src})")
        for j in jobs:
            ops = [o.Label for o in getattr(j.Operations, "Group", [])]
            print(f"  job {j.Name!r} (label {j.Label!r})")
            print(f"    machine:   {getattr(j, 'Machine', '') or '<unset>'}")
            print(f"    post:      {j.PostProcessor or '<unset>'}")
            print(f"    operations: {len(ops)}  {', '.join(ops)}")
        print("\nAvailable machines:")
        for name, path in MachineFactory.list_configuration_files():
            if path is not None:
                print(f"  {name}")
        return 0

    if not jobs:
        sys.stderr.write(f"error: no CAM job in {src}\n")
        return 1

    if job_names:
        selected = []
        for wanted in job_names:
            found = _find_job(jobs, wanted)
            if found is None:
                available = ", ".join(f"{j.Label!r}" for j in jobs)
                sys.stderr.write(
                    f"error: no job matching {wanted!r} in {src}; have {available}\n"
                )
                return 1
            if isinstance(found, list):
                sys.stderr.write(
                    f"error: {wanted!r} matches {len(found)} jobs "
                    f"({', '.join(j.Name for j in found)}); select by object name\n"
                )
                return 1
            selected.append(found)
    else:
        selected = jobs

    # A machine loaded from an explicit file never needs the asset store; the
    # Job.Machine string is still set so the post's own header logic sees it.
    machine = None
    if machine_file and not legacy_post:
        data = MachineFactory.load_configuration(machine_file)
        machine = Machine.from_dict(data) if isinstance(data, dict) else data

    rc = 0
    for job in selected:
        if legacy_post:
            # Old flow: the post comes from the job property and there is no
            # machine involved. export() rather than export2().
            job.PostProcessor = legacy_post
            doc.recompute()
            processor = PostProcessorFactory.get_post_processor(job, legacy_post)
            sections = processor.export()
            _write_sections(sections, out, doc, job, len(selected), legacy_post)
            if not sections:
                rc = 1
            continue

        if machine is not None:
            job.Machine = machine.name
        elif machine_name:
            job.Machine = machine_name
        if not job.Machine:
            sys.stderr.write(
                f"error: job {job.Name!r} has no machine set; pass --machine or --machine-file\n"
            )
            return 1
        doc.recompute()

        resolved = machine if machine is not None else MachineFactory.get_machine(job.Machine)
        postname = resolved.postprocessor_file_name
        if not postname:
            sys.stderr.write(f"error: machine {resolved.name!r} names no postprocessor\n")
            return 1

        processor = PostProcessorFactory.get_post_processor(job, postname)
        if machine is not None:
            # __init__ resolved (or failed to resolve) the machine through the
            # asset store; swap in the one we loaded and rebuild from it.
            processor._machine = machine
            processor.reinitialize()

        sections = processor.export2()
        if not _write_sections(sections, out, doc, job, len(selected), postname):
            rc = 1
    return rc


def _write_sections(sections, out, doc, job, n_jobs, postname):
    if not sections:
        sys.stderr.write(f"error: post returned nothing for job {job.Name!r}\n")
        return False
    for section, gcode in sections:
        path = _output_path(out, doc, job, section, n_jobs, len(sections))
        with open(path, "w") as fh:
            fh.write(gcode or "")
        lines = len((gcode or "").splitlines())
        print(f"{path}  ({job.Label}/{section}, {lines} lines, post={postname})")
    return True


def _find_job(jobs, wanted):
    """Resolve a -j value to one job.

    Matched against the label first, since that is what the CAM tree shows and
    what a user will reach for; the internal object name is accepted as a
    fallback and as the way to disambiguate duplicate labels. Returns the job,
    None if nothing matched, or the list of candidates if several did.
    """
    by_label = [j for j in jobs if j.Label == wanted]
    if len(by_label) == 1:
        return by_label[0]
    if len(by_label) > 1:
        return by_label
    for j in jobs:
        if j.Name == wanted:
            return j
    return None


def _slug(label):
    """Make a label safe to embed in a filename."""
    return "".join(c if c.isalnum() or c in "-." else "_" for c in label).strip("_")


def _output_path(out, doc, job, section, n_jobs, n_sections):
    """Pick a filename, only decorating it when one run produces several files."""
    if out and n_jobs == 1 and n_sections == 1:
        return out
    stem, ext = os.path.splitext(out or f"{doc.Name}.gcode")
    ext = ext or ".gcode"
    parts = [stem]
    if n_jobs > 1:
        parts.append(_slug(job.Label) or job.Name)
    if section and section != "allitems":
        parts.append(section)
    return "_".join(parts) + ext


# --------------------------------------------------------------------------
# Stage 1: running under plain python3, find FreeCAD and re-exec.
# --------------------------------------------------------------------------
def find_freecadcmd():
    if os.environ.get("FREECADCMD"):
        return [os.environ["FREECADCMD"]]

    weeklies = sorted(
        glob.glob(os.path.expanduser("~/Downloads/FreeCAD_weekly-*-Linux-x86_64.AppImage"))
    )
    if weeklies:
        # The AppImage runs the GUI binary by default; -c selects console mode.
        return [weeklies[-1], "-c"]

    for name in ("freecadcmd", "FreeCADCmd", "freecad.cmd"):
        for d in os.environ.get("PATH", "").split(os.pathsep):
            p = os.path.join(d, name)
            if os.path.isfile(p) and os.access(p, os.X_OK):
                return [p]

    sys.exit(
        "error: no FreeCAD console binary found. Set FREECADCMD to one, e.g.\n"
        "  FREECADCMD=~/Downloads/FreeCAD_weekly-2026.09.16-Linux-x86_64.AppImage"
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("source", help="FCStd file containing the CAM job")
    ap.add_argument("-o", "--out", help="output G-code file (default <document>.gcode)")
    ap.add_argument("-j", "--job", action="append", default=[],
                    help="job label (as shown in the CAM tree) or object name, "
                         "repeatable (default: every job in the document)")
    ap.add_argument("-m", "--machine", help="machine display name from the CAM asset store")
    ap.add_argument("-M", "--machine-file", help="path to a .fcm, bypassing the asset store")
    ap.add_argument("-p", "--legacy-post",
                    help="post via the legacy flow with this post name (e.g. "
                         "millennium_os_legacy); ignores --machine/--machine-file")
    ap.add_argument("--post-dir", default=REPO_POST_DIR,
                    help="directory searched first for the post module (default: this repo)")
    ap.add_argument("--no-post-dir", action="store_true",
                    help="use only FreeCAD's normal post search path")
    ap.add_argument("--list", action="store_true",
                    help="list the jobs and available machines, then exit")
    args = ap.parse_args()

    env = dict(os.environ)
    env["MOS_SRC"] = os.path.abspath(args.source)
    env["MOS_JOBS"] = "\n".join(args.job)
    env["MOS_OUT"] = os.path.abspath(args.out) if args.out else ""
    env["MOS_MACHINE"] = args.machine or ""
    env["MOS_MACHINE_FILE"] = os.path.abspath(args.machine_file) if args.machine_file else ""
    env["MOS_LEGACY_POST"] = args.legacy_post or ""
    env["MOS_POST_DIR"] = "" if args.no_post_dir else os.path.abspath(args.post_dir)
    env["MOS_LIST"] = "1" if args.list else "0"
    env["MOS_INSIDE"] = "1"

    cmd = find_freecadcmd() + [os.path.abspath(__file__)]
    os.execve(cmd[0], cmd, env)


# FreeCAD's script runner execs this file without setting __name__ to
# "__main__", so the inside-FreeCAD branch cannot be guarded on that.
if os.environ.get("MOS_INSIDE") == "1":
    _rc = run_inside_freecad() or 0
    if _rc:
        sys.exit(_rc)
elif __name__ == "__main__":
    main()
