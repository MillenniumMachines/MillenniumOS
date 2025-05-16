<template>
    <v-card>
        <v-card-title>
            <v-icon large left>{{ probeType.icon }}</v-icon>
            <h3>{{ probeType.name }}</h3>
        </v-card-title>
        <v-container fluid>
            <v-form ref="probeSettings">
                <v-row>
                    <v-col cols="12" md="6" v-for="(setting, name, index) in probeType.settings" :key="index">
                        <v-row>
                            <v-col :id="index">
                                <v-subheader>{{ setting.label ?? 'Unknown' }}</v-subheader>
                                <v-row v-if="isNumberSetting(setting)">
                                    <v-col cols="8" md="10">
                                        <v-slider
                                            class="mt-4"
                                            v-model="setting.value"
                                            :min="setting.min"
                                            :max="setting.max"
                                            :step="setting.step"
                                            :hint="setting.description"
                                            :prepend-icon="setting.icon"
                                            :disabled="!allowInput(name)"
                                            @input="setting.value = $event"
                                            thumb-label
                                            persistent-hint
                                        >
                                        </v-slider>
                                    </v-col>
                                    <v-col cols="4" md="2">
                                        <v-text-field
                                            class="pt-0 mt-0"
                                            v-model="setting.value"
                                            :suffix = "setting.unit"
                                            @input="setting.value = $event"
                                        ></v-text-field>
                                    </v-col>
                                </v-row>
                                <v-row v-else-if="isBooleanSetting(setting)">
                                    <v-col cols="8" md="10">
                                        <v-switch
                                            v-model="setting.value"
                                            @change="setting.value = $event"
                                            :hint="setting.description"
                                            :prepend-icon="setting.icon"
                                            :disabled="!allowInput(name)"
                                            persistent-hint
                                            class="mt-0"
                                        >
                                        </v-switch>
                                    </v-col>
                                    <v-col cols="4" md="2" class="text-right">
                                        <v-tooltip top>
                                            <template v-slot:activator="{ on, attrs }">
                                                <v-btn
                                                    :color="setting.value ? 'primary' : 'secondary'"
                                                    label
                                                    v-on="on"
                                                    small
                                                    style="pointer-events: none"
                                                >
                                                    <v-icon
                                                        v-on="on"
                                                    >
                                                        {{  setting.value ? 'mdi-check' : 'mdi-close' }}
                                                    </v-icon>
                                                </v-btn>
                                            </template>
                                            {{ setting.value ? $t("plugins.millenniumos.probeSettings.booleanEnabled") : $t("plugins.millenniumos.probeSettings.booleanDisabled") }}
                                        </v-tooltip>
                                    </v-col>
                                </v-row>
                                <v-row v-else-if="isEnumSetting(setting)">
                                    <v-col cols="8" md="10">
                                        <v-input
                                            :prepend-icon="setting.icon"
                                        >
                                            <v-chip-group
                                                    v-model="setting.value"
                                                    mandatory
                                                    column
                                                    class="ml-4 px-0 py-0 mt-n3"
                                                    >
                                                <v-tooltip v-for="(option, i) in setting.options" :key="i" top>
                                                    <template v-slot:activator="{ on, attrs }">
                                                        <v-chip
                                                            v-on="on"
                                                            :key="i"
                                                            :value="i"
                                                            :color="getEnumColor(i, setting.value)"
                                                            :disabled="!allowInput(name)"
                                                            label
                                                            small
                                                            class="mt-2 mb-0 pl-0 pr-1"
                                                            >
                                                            <v-icon class="px-0">{{ getEnumIcon(option) }}</v-icon>
                                                            {{ getEnumText(option) }}
                                                        </v-chip>
                                                    </template>
                                                    <span>{{ getEnumText(option) }}</span>
                                                </v-tooltip>
                                            </v-chip-group>
                                        </v-input>
                                    </v-col>
                                    <v-col cols="4" md="2" class="text-right">
                                        <v-tooltip top>
                                            <template v-slot:activator="{ on, attrs }">
                                                <v-btn
                                                    :color="getEnumColor(setting.value, setting.value)"
                                                    label
                                                    small
                                                    v-on="on"
                                                    style="pointer-events: none"
                                                >
                                                    <v-icon
                                                        v-on="on"
                                                    >
                                                        {{ getEnumIcon(setting.options[setting.value]) }}
                                                    </v-icon>
                                                </v-btn>
                                            </template>
                                            {{ getEnumText(setting.options[setting.value]) }}
                                        </v-tooltip>
                                    </v-col>
                                </v-row>
                            </v-col>
                        </v-row>
                    </v-col>
                </v-row>
            </v-form>
        </v-container>
        <v-card-actions>
            <v-spacer></v-spacer>
            <v-btn @click="updateProbeSettings()" color="primary">
                Continue <v-icon>mdi-forward</v-icon>
            </v-btn>
        </v-card-actions>
    </v-card>

</template>
<script lang="ts">
    import { PropType } from "vue";

    import BaseComponent from "../BaseComponent.vue";

    import { Axis, AxisLetter } from "@duet3d/objectmodel";

    import store from "@/store";

    import { defineComponent } from 'vue'

    import { ProbeType, OptionOrString, hasOptionIcon, ProbeCommand, ProbeSettingAll, isBooleanSetting, isEnumSetting, isNumberSetting } from "../../types/Probe";

    const colors = ['pink','blue','teal','green','blue-grey','deep-orange','indigo', 'red','purple'];

    export default defineComponent({
        extends: BaseComponent,
        props: {
            value: {
                type: Object as PropType<ProbeCommand>,
                required: true
            },
            probeType: {
                type: Object as PropType<ProbeType>,
                required: true
            },
        },
        computed: {
		    uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		    allAxesHomed(): boolean { return store.state.machine.model.move.axes.every(axis => axis.visible && axis.homed)},
            visibleAxesByLetter(): { [key in AxisLetter]: Axis } {
                return store.state.machine.model.move.axes.filter(axis => axis.visible).reduce((acc, axis) => {
                    acc[axis.letter] = axis;
                    return acc;
                }, {} as { [key in AxisLetter]: Axis });
            },
        },
        data() {
            return {}
        },
        methods: {
            allowInput( settingName: string | number ): boolean {
                let curSetting = this.probeType.settings[settingName] as ProbeSettingAll;

                // If setting has no condition or refers to itself, always allow input
                if(!curSetting.condition || curSetting.condition === settingName) {
                    return true;
                }

                let conditionSetting = this.probeType.settings[curSetting.condition];

                // Otherwise, allow input if condition is met. Default to true if conditionValue is not defined
                let conditionValue = (typeof curSetting.conditionValue == "undefined")? true : curSetting.conditionValue;
                return conditionSetting.value === conditionValue;
            },
            isNumberSetting: isNumberSetting,
            isBooleanSetting: isBooleanSetting,
            isEnumSetting: isEnumSetting,
            getEnumColor(key: number, current: number): string {
                // Darken the colour if the current value is the same as the key
                return colors[key % colors.length] + (key === current ? ' lighten-2' : '');
            },
            getEnumText(opt: OptionOrString): string {
                if(hasOptionIcon(opt)) {
                    return opt.label;
                }
                return opt;
            },
            getEnumIcon(opt: OptionOrString): string {
                if(hasOptionIcon(opt)) {
                    return opt.icon;
                }
                return 'mdi-border-radius';
            },
            updateProbeSettings() {
                this.$emit('change');
            },
        }
    });
</script>
