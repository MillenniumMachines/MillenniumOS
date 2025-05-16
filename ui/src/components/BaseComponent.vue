
<script lang="ts">
    import { Axis, AxisLetter, Tool } from "@duet3d/objectmodel";

    import { defineComponent } from 'vue'

    import { workplaceAsGCode } from "../utils/display";

    import store from "@/store";

    export default defineComponent({
        props: {},
        computed: {
		    uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		    allAxesHomed(): boolean { return store.state.machine.model.move.axes.every(axis => axis.visible && axis.homed)},
            visibleAxesByLetter(): { [key in AxisLetter]: Axis } {
                return store.state.machine.model.move.axes.filter(axis => axis.visible).reduce((acc, axis) => {
                    acc[axis.letter] = axis;
                    return acc;
                }, {} as { [key in AxisLetter]: Axis });
            },
            currentTool(): Tool | null {
                const toolIndex = store.state.machine.model.state.currentTool;
                return toolIndex < 0 ? null : store.state.machine.model.tools[toolIndex];
            },
            probeTool(): Tool | null {
                const ptID = store.state.machine.model.global.get("mosPTID") ?? -1;
                if (ptID < 0 || (ptID >= (store.state.machine.model.limits?.tools ?? 0))) {
                    return null;
                }
                return store.state.machine.model.tools[ptID];
            },
            currentWorkplace: {
                get(): number {
                    return store.state.machine.model.move.workplaceNumber;
                },
                async set(value: number) {
                    await this.sendCode(workplaceAsGCode(value));
                }
            },
            absolutePosition(): { [key in AxisLetter]: number } {
                const axes = this.visibleAxesByLetter;

                return Object.keys(axes).reduce((acc, key) => {
                    const axis: Axis = axes[key as AxisLetter];
                    // const toolOffset = this.currentTool ? this.currentTool.offsets[axis.] ?? 0 : 0;
                    const toolOffset = 0;
                    acc[key as AxisLetter] = axis.workplaceOffsets[this.currentWorkplace] + (axis.userPosition ?? 0) + toolOffset;
                    return acc;
                }, {} as { [key in AxisLetter]: number });
            },
        },
        data() {
            return {}
        },
        methods: {
            async sendCode(code: string): Promise<string> {
                return await store.dispatch("machine/sendCode", code);
            },
        }
    });
</script>
