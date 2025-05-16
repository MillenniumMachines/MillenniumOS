const DS_OVERTRAVEL = 'overtravel';
const DS_SURFACE_CLEARANCE = 'surface-clearance';
const DS_EDGE_CLEARANCE = 'edge-clearance';
const DS_CORNER_CLEARANCE = 'corner-clearance';
const DS_QUICK = 'quick';

export const valueSettings = {

    [DS_QUICK]: {
        type: 'boolean',
        label: 'Quick Mode',
        description: 'If enabled, only a single probe point will be performed on each surface. Angle calculations will not be performed. Turn this off for more accurate probe results.',
        parameter: 'Q',
        icon: 'mdi-clock-fast',
        value: true,
    },
    [DS_OVERTRAVEL]: {
        type: 'number',
        label: 'Overtravel',
        description: 'The distance the probe will travel past the expected edge of the feature or workpiece, to account for inaccuracies in the starting position or feature dimensions.',
        parameter: 'O',
        icon: 'mdi-unfold-less-vertical',
        value: 2,
        min: 1,
        max: 20,
        step: 0.1,
        unit: 'mm'
    },
    [DS_SURFACE_CLEARANCE]: {
        type: 'number',
        label: 'Surface Clearance',
        description: 'The distance the probe will move inwards towards the expected surface of the feature or workpiece, to account for inaccuracies in the starting position or work holding.',
        parameter: 'T',
        icon: 'mdi-unfold-more-vertical',
        value: 10,
        min: 2,
        max: 50,
        step: 0.1,
        unit: 'mm'
    },
    [DS_CORNER_CLEARANCE]: {
        type: 'number',
        label: 'Corner Clearance',
        description: 'The distance the probe will move inwards from the expected corner of the feature or workpiece, to account for inaccuracies in the starting position or corner radiuses.',
        parameter: 'C',
        icon: 'mdi-unfold-more-horizontal',
        value: 5,
        min: 1,
        max: 50,
        step: 0.1,
        unit: 'mm'
    },
    [DS_EDGE_CLEARANCE]: {
        type: 'number',
        label: 'Edge Clearance',
        description: 'The distance the probe will move inwards from the expected edge of the feature or workpiece, to account for inaccuracies in the starting position.',
        parameter: 'C',
        icon: 'mdi-unfold-more-horizontal',
        value: 5,
        min: 1,
        max: 50,
        step: 0.1,
        unit: 'mm',
        condition: 'quick',
        conditionValue: false,
    }
};

// Not used as these need to be
// arrays of strings.
export enum cornerNames {
    "Front Left",
    "Front Right",
    "Back Right",
    "Back Left"
}

export enum surfaceNames {
    "Left",
    "Right",
    "Front",
    "Back",
    "Top"
}

export type Option = {
    icon: string;
    label: string;
}

export type OptionOrString = string | Option;

export function hasOptionIcon(option: OptionOrString): option is Option {
    return (option as Option).icon !== undefined;
}

export type ProbeSetting = {
    type: string;
    label: string;
    description: string;
    parameter?: string;
    icon?: string;
    min?: number;
    max?: number;
    multiplier?: number;
    step?: number;
    unit?: string;
    options?: OptionOrString[];
    condition?: string;
    conditionValue?: boolean;
}

export type ProbeSettingBoolean = ProbeSetting & {
    type: 'boolean';
    value: boolean;
};

export type ProbeSettingNumber = ProbeSetting & {
    type: 'number';
    value: number;
};

export type ProbeSettingEnum = ProbeSetting & {
    type: 'enum';
    value: number;
};

export type ProbeSettingAll = ProbeSettingBoolean | ProbeSettingNumber | ProbeSettingEnum;

export type ProbeSettings = {
    [key: string]: ProbeSettingAll;
}

// If a ProbeSettingModifier is provided to
// ProbeCommand.toGCode(), the operator-provided
// value will be used as a modifier on the value
// provided in the modifier rather than the static
// value in the setting.
// This allows for things like 'depth' settings to
// output an absolute co-ordinate based on the current
// position, supplied as a modifier.
export type ProbeSettingNumberModifier = {
    numberValue: number;
}

export type ProbeSettingModifier = ProbeSettingNumberModifier;

export function isNumberModifier(mod: ProbeSettingModifier): mod is ProbeSettingNumberModifier {
    return mod.numberValue !== undefined;
}

export type ProbeSettingsModifier = {
    [key: string]: ProbeSettingModifier;
}

export interface IProbeCommand {
    command: number;
    settings: ProbeSettings,
    addSetting: (id: string, setting: ProbeSettingAll) => void;
    addSettings: (settings: ProbeSettings) => void;
    toGCode: (mods: ProbeSettingsModifier | null) => string;
}

export class ProbeCommand implements IProbeCommand {
    command: number;
    settings: ProbeSettings;

    constructor(command: number, settings: ProbeSettings | null) {
        this.command = command;
        this.settings = (settings) ? settings : {};
    }

    addSetting(id: string, setting: ProbeSettingAll) {
        this.settings[id] = setting;
    }

    addSettings(settings: ProbeSettings) {
        this.settings = settings;
    }

    toGCode(mods: ProbeSettingsModifier | null): string {
        const gcode: string[] = [`G${this.command.toString()}`];
        for (const key in this.settings) {
            const setting = this.settings[key];

            // Dont include settings without a parameter
            if (setting.parameter === undefined) {
                continue;
            }

            // Dont include settings whose conditional setting does
            // not match the conditionValue.
            if (setting.condition && this.settings[setting.condition].value !== setting.conditionValue) {
                continue;
            }

            const p = setting.parameter;
            const v = setting.value;
            const m = setting.multiplier ? setting.multiplier : 1;

            if (isBooleanSetting(setting)) {
                gcode.push(`${p}${v ? 1 : 0}`);
            } else if (isNumberSetting(setting)) {
                if (mods && p in mods && isNumberModifier(mods[p])) {
                    gcode.push(`${p}${((v as number) * m) + mods[p].numberValue}`);
                } else {
                    gcode.push(`${p}${v}`);
                }
            } else if (isEnumSetting(setting)) {
                gcode.push(`${p}${v}`);
            }
        }
        return gcode.join(' ');
    }
}

export function isBooleanSetting(setting: ProbeSetting): setting is ProbeSettingBoolean {
    return setting.type === 'boolean';
}

export function isNumberSetting(setting: ProbeSetting): setting is ProbeSettingNumber {
    return setting.type === 'number';
}

export function isEnumSetting(setting: ProbeSetting): setting is ProbeSettingEnum {
    return setting.type === 'enum';
}

export type ProbeType = {
    name: string;
    icon: string;
    description: string;
    code: number;
    settings: ProbeSettings;
}

export type ProbeTypes = {
    [key:string]: ProbeType;
}

export default {
    bore: <ProbeType> {
        name: 'Bore',
        icon: 'mdi-circle-outline',
        description: 'Finds the center of a circular bore (negative feature) by probing its inner diameter.',
        code: 6500.1,
        // G6500.1 W{var.workOffset} H{var.boreDiameter} O{var.overTravel} J{global.mosMI[0]} K{global.mosMI[1]} L{global.mosMI[2] - var.probingDepth}
        settings: {
            'diameter': {
                type: 'number',
                label: 'Diameter',
                description: 'The approximate diameter of the bore.',
                parameter: 'H',
                icon: 'mdi-diameter-variant',
                value: 10,
                min: 1,
                max: 100,
                step: 0.1,
                unit: 'mm'
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    },
    boss: <ProbeType> {
        name: 'Boss',
        icon: 'mdi-circle',
        description: 'Finds the center of a circular boss (positive feature or workpiece) by probing its outer diameter.',
        code: 6501.1,
        settings: {
            'diameter': {
                type: 'number',
                label: 'Diameter',
                description: 'The approximate diameter of the boss.',
                parameter: 'H',
                icon: 'mdi-diameter-variant',
                value: 10,
                min: 1,
                max: 100,
                step: 0.1,
                unit: 'mm'
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    },
    rectanglePocket: <ProbeType> {
        name: 'Rectangle Pocket',
        icon: 'mdi-rectangle-outline',
        description: 'Finds the center of a rectangular pocket (negative feature) by probing its inner surfaces.',
        code: 6502.1,
        settings: {
            'width': {
                type: 'number',
                label: 'Width (on X axis)',
                description: 'The approximate width of the pocket (measured parallel to the X axis).',
                parameter: 'H',
                icon: 'mdi-unfold-more-vertical',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm'
            },
            'length': {
                type: 'number',
                label: 'Length (on Y axis)',
                description: 'The approximate length of the pocket (measured parallel to the Y axis).',
                parameter: 'I',
                icon: 'mdi-unfold-more-horizontal',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm'
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_CORNER_CLEARANCE]: valueSettings[DS_CORNER_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    },
    rectangleBlock: <ProbeType> {
        name: 'Rectangle Block',
        icon: 'mdi-rectangle',
        description: 'Finds the center of a rectangular block (positive feature or workpiece) by probing its outer surfaces.',
        code: 6503.1,
        settings: {
            'width': {
                type: 'number',
                label: 'Width (on X axis)',
                description: 'The approximate width of the block (measured parallel to the X axis).',
                parameter: 'H',
                icon: 'mdi-unfold-more-vertical',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm'
            },
            'length': {
                type: 'number',
                label: 'Length (on Y axis)',
                description: 'The approximate length of the block (measured parallel to the Y axis).',
                parameter: 'I',
                icon: 'mdi-unfold-more-horizontal',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm'
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_CORNER_CLEARANCE]: valueSettings[DS_CORNER_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    },
    web: <ProbeType> {
        name: 'Web',
        icon: 'mdi-math-norm-box',
        description: 'Finds the center of a web (positive rectangular feature) on one axis by probing its outer surfaces.',
        code: 6504.1,
        settings: {
            [DS_QUICK]: valueSettings[DS_QUICK],
            'axis': {
                type: 'enum',
                label: 'Axis',
                description: 'The axis of the web.',
                parameter: 'N',
                icon: 'mdi-axis-arrow',
                value: 0,
                options: [
                    {
                        icon: 'mdi-swap-horizontal',
                        label: 'X'
                    },
                    {
                        icon: 'mdi-swap-vertical',
                        label: 'Y'
                    }
                ]
            },
            'width': {
                type: 'number',
                label: 'Width',
                description: 'The approximate width of the web. This is how far outwards along the probed axis we will move before probing back towards the web surfaces.',
                parameter: 'H',
                icon: 'mdi-unfold-less-vertical',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
            },
            'length': {
                type: 'number',
                label: 'Length',
                description: 'The approximate length of the web surfaces. With quick mode disabled, this is used to calculate the probe locations on the web surfaces.',
                parameter: 'I',
                icon: 'mdi-unfold-less-horizontal',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
                condition: 'quick',
                conditionValue: false,
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_EDGE_CLEARANCE]: valueSettings[DS_EDGE_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        }
    },
    pocket: <ProbeType> {
        name: 'Pocket',
        icon: 'mdi-math-norm',
        description: 'Finds the center of a pocket (negative rectangular feature) on one axis by probing its inner surfaces.',
        code: 6505.1,
        settings: {
            [DS_QUICK]: valueSettings[DS_QUICK],
            'axis': {
                type: 'enum',
                label: 'Axis',
                description: 'The axis of the pocket.',
                parameter: 'N',
                icon: 'mdi-axis-arrow',
                value: 0,
                options: [
                    {
                        icon: 'mdi-swap-horizontal',
                        label: 'X'
                    },
                    {
                        icon: 'mdi-swap-vertical',
                        label: 'Y'
                    }
                ]
            },
            'width': {
                type: 'number',
                label: 'Width',
                description: 'The approximate width of the pocket. This defines how far outwards we expect the probed surfaces to be from the start point, minus the clearance distance.',
                parameter: 'H',
                icon: 'mdi-unfold-less-vertical',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
            },
            'length': {
                type: 'number',
                label: 'Length',
                description: 'The approximate length of the pocket surfaces. With quick mode disabled, this is used to calculate the probe locations on the pocket surfaces.',
                parameter: 'I',
                icon: 'mdi-unfold-less-horizontal',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
                condition: 'quick',
                conditionValue: false,
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_EDGE_CLEARANCE]: valueSettings[DS_EDGE_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        }
    },
    outsideCorner: <ProbeType> {
        name: 'Outside Corner',
        icon: 'mdi-square-rounded-badge',
        description: 'Finds the corner of a positive feature or workpiece by probing its outer surfaces.',
        code: 6508.1,
        // G6508.1 W{var.workOffset} Q{var.mode} H{var.xSL} I{var.ySL} N{var.cnr} T{var.SurfaceClearance} C{var.cornerClearance} O{var.overtravel} J{global.mosMI[0]} K{global.mosMI[1]} L{global.mosMI[2] - var.probingDepth}
        settings: {
            [DS_QUICK]: { ...valueSettings[DS_QUICK], value: false },
            'corner': {
                type: 'enum',
                label: 'Corner',
                description: 'The corner of the workpiece.',
                parameter: 'N',
                icon: 'mdi-rounded-corner',
                value: 0,
                options: [
                    {
                        icon: 'mdi-arrow-bottom-left-bold-box',
                        label: 'Front Left'
                    },
                    {
                        icon: 'mdi-arrow-bottom-right-bold-box',
                        label: 'Front Right'
                    },
                    {
                        icon: 'mdi-arrow-top-right-bold-box',
                        label: 'Back Right'
                    },
                    {
                        icon: 'mdi-arrow-top-left-bold-box',
                        label: 'Back Left'
                    }
                ]
            },
            'width': {
                type: 'number',
                label: 'Width',
                description: 'The approximate length of the X surface of the corner.',
                parameter: 'H',
                icon: 'mdi-unfold-more-vertical',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
                condition: 'quick',
                conditionValue: false,
            },
            'length': {
                type: 'number',
                label: 'Length',
                description: 'The approximate length of the Y surface of the corner.',
                parameter: 'I',
                icon: 'mdi-unfold-more-horizontal',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
                condition: 'quick',
                conditionValue: false,
            },
            'depth': {
                type: 'number',
                label: 'Depth (from starting position)',
                description: 'How far to move down from the starting position before probing.',
                parameter: 'Z',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                multiplier: -1,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_CORNER_CLEARANCE]: valueSettings[DS_CORNER_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    },
    viseCorner: <ProbeType> {
        name: 'Vise Corner',
        icon: 'mdi-cube',
        description: 'Finds the top and corner of a positive feature or workpiece by probing its top and outer surfaces.',
        code: 6520.1,
        settings: {
            [DS_QUICK]: valueSettings[DS_QUICK],
            'corner': {
                type: 'enum',
                label: 'Corner',
                description: 'The corner of the workpiece.',
                parameter: 'N',
                icon: 'mdi-rounded-corner',
                value: 0,
                options: [
                    {
                        icon: 'mdi-arrow-bottom-left-bold-box',
                        label: 'Front Left'
                    },
                    {
                        icon: 'mdi-arrow-bottom-right-bold-box',
                        label: 'Front Right'
                    },
                    {
                        icon: 'mdi-arrow-top-right-bold-box',
                        label: 'Back Right'
                    },
                    {
                        icon: 'mdi-arrow-top-left-bold-box',
                        label: 'Back Left'
                    }
                ]
            },
            'width': {
                type: 'number',
                label: 'Width',
                description: 'The approximate length of the X surface of the corner.',
                icon: 'mdi-unfold-more-vertical',
                parameter: 'H',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
                condition: 'quick',
                conditionValue: false,
            },
            'length': {
                type: 'number',
                label: 'Length',
                description: 'The approximate length of the Y surface of the corner.',
                icon: 'mdi-unfold-more-horizontal',
                parameter: 'I',
                value: 10,
                min: 0,
                max: 300,
                step: 0.1,
                unit: 'mm',
                condition: 'quick',
                conditionValue: false,
            },
            'depth': {
                type: 'number',
                label: 'Depth (from top surface)',
                description: 'How far to move down from the top surface of the corner before probing the sides.',
                parameter: 'P',
                icon: 'mdi-arrow-down-bold-circle',
                value: 5,
                min: 0,
                max: 20,
                step: 0.1,
                unit: 'mm'
            },
            [DS_SURFACE_CLEARANCE]: valueSettings[DS_SURFACE_CLEARANCE],
            [DS_CORNER_CLEARANCE]: valueSettings[DS_CORNER_CLEARANCE],
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    },
    singleSurface: <ProbeType> {
        name: 'Single Surface',
        icon: 'mdi-square-opacity',
        description: 'Finds the co-ordinate of a surface at one point.',
        code: 6510.1,
        settings: {
            'surface': {
                type: 'enum',
                label: 'Surface',
                description: 'The surface s towards the..',
                parameter: 'H',
                icon: 'mdi-square-opacity',
                value: 0,
                options: [
                    {
                        label: 'Left',
                        icon: 'mdi-arrow-left-bold'
                    },
                    {
                        label: 'Right',
                        icon: 'mdi-arrow-right-bold'
                    },
                    {
                        label: 'Front',
                        icon: 'mdi-arrow-down-bold'
                    },
                    {
                        label: 'Back',
                        icon: 'mdi-arrow-up-bold'
                    },
                    {
                        label: 'Top',
                        icon: 'mdi-circle-box'
                    }
                ]
            },
            'distance': {
                type: 'number',
                label: 'Distance',
                description: 'The approximate distance to move towards the target surface.',
                icon: 'mdi-ruler',
                parameter: 'I',
                value: 10,
                min: 1,
                max: 100,
                step: 0.1,
                unit: 'mm'
            },
            [DS_OVERTRAVEL]: valueSettings[DS_OVERTRAVEL]
        },
    }
} as ProbeTypes;