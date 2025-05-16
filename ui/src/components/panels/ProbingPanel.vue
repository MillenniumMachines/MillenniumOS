<style lang="css">
.v-progress-linear.animate .v-progress-linear__determinate
{
    animation: move 5s linear infinite;
}
@keyframes move {
    0% {
        background-position: 0 0;
    }
    100% {
        background-position: 100px 100px;
    }
}
</style>
<template>
    <v-card>
        <v-card-title>
            <v-icon large class="mr-1">mdi-target-variant</v-icon>
            Probing
            <v-spacer />
            <code-btn small :color="allAxesHomed ? 'primary' : 'warning'" code="G28"
                    :title="$t('button.home.titleAll')">
                {{ $t("button.home.captionAll") }}
            </code-btn>
        </v-card-title>
        <v-card-text :class="{'px-0': $vuetify.breakpoint.mdAndDown}">
            <v-container fluid>
                <v-row>
                    <v-col cols="12">
                        <v-tabs v-model="tab">
                            <v-tab :disabled="probeActive || probing">
                                <v-icon left>mdi-swap-horizontal</v-icon>
                                Activate Probe
                            </v-tab>

                            <v-tab :disabled="!probeActive || probing">
                                <v-icon left>mdi-target-variant</v-icon>
                                Select Cycle
                            </v-tab>

                            <v-tab :disabled="!probeActive || !hasProbeTypeSelected || probing">
                                <v-icon left>mdi-cog</v-icon>
                                Configure Settings
                            </v-tab>
                            <v-tab :disabled="!probeActive || !hasProbeTypeSelected || probing">
                                <v-icon left>mdi-run-fast</v-icon>
                                Move to Position
                            </v-tab>
                            <v-tab :disabled="!probeActive || !hasProbeTypeSelected || !hasProbeCommand || probing">
                                <v-icon left>mdi-check</v-icon>
                                Review and Run
                            </v-tab>
                            <v-tab :disabled="!probing || !probeActive || !hasProbeTypeSelected || !hasProbeCommand || !hasStatus">
                                <v-icon left>mdi-state-machine</v-icon>
                                Status
                            </v-tab>

                            <v-tab-item>

                                <v-btn
                                    class="mt-4 mx-4"
                                    v-if="!probeActive"
                                    @click="activateProbe"
                                    color="success"
                                    :loading="probing"
                                    >Activate Probe <v-icon>mdi-swap-horizontal</v-icon>
                                </v-btn>

                            </v-tab-item>
                            <v-tab-item>
                                <mos-probe-selector-panel :probeTypes="probeTypes"
                                    @change="selectProbeType"
                                />
                            </v-tab-item>


                            <v-tab-item>
                                <mos-probe-settings-panel
                                    v-if="hasProbeCommand"
                                    :probeType="probeType"
                                    v-model="probeCommand"
                                    @change="nextStep"
                                />
                            </v-tab-item>

                            <v-tab-item>
                                <v-card>
                                    <v-card-title>Move to Position</v-card-title>
                                    <v-card-text>
                                        <cnc-movement-panel />
                                    </v-card-text>
                                    <v-card-actions>
                                        <v-spacer></v-spacer>
                                        <v-btn @click="nextStep" color="primary">
                                            Continue <v-icon>mdi-forward</v-icon>
                                        </v-btn>
                                    </v-card-actions>
                                </v-card>
                            </v-tab-item>

                            <v-tab-item v-if="hasProbeCommand">
                                <v-card>
                                    <v-card-title>Review</v-card-title>
                                    <v-card-text>
                                        <pre v-if="!probing">{{ getProbeCode() }}</pre>
                                    </v-card-text>
                                    <v-card-actions>
                                        <v-spacer></v-spacer>
                                        <v-btn
                                            v-if="probeActive"
                                            @click="runProbe"
                                            color="primary"
                                            :loading="probing"
                                            >
                                            Run Cycle <v-icon>mdi-arrow-collapse-all</v-icon>
                                        </v-btn>
                                    </v-card-actions>
                                </v-card>
                            </v-tab-item>
                            <v-tab-item v-if="hasStatus">
                                <v-progress-linear
                                    v-if="probeRetryTotal > 1"
                                    class="mt-4 animate"
                                    color="warning"
                                    rounded
                                    v-model="probeRetryProgress"
                                    height=25
                                    style="pointer-events: none"
                                    striped
                                    stream
                                    :buffer-value="probeRetryBuffer"
                                    >
                                    <strong>Sample {{ Math.min(probeRetryCurrent+1, probeRetryTotal) }} / {{ probeRetryTotal }}</strong>
                                </v-progress-linear>
                                <v-progress-linear
                                    class="mt-4 animate"
                                    color="primary"
                                    rounded
                                    v-model="probePointProgress"
                                    height=25
                                    style="pointer-events: none"
                                    striped
                                    stream
                                    :buffer-value="probePointBuffer"
                                    >
                                    <strong>Point {{ Math.min(probePointCurrent+1, probePointTotal) }} / {{ probePointTotal }}</strong>
                                </v-progress-linear>
                                <v-progress-linear
                                    class="mt-4 animate"
                                    color="success"
                                    rounded
                                    v-model="probeSurfaceProgress"
                                    height=25
                                    style="pointer-events: none"
                                    striped
                                    stream
                                    :buffer-value="probeSurfaceBuffer"
                                    >
                                    <strong>Surface {{ Math.min(probeSurfaceCurrent+1, probeSurfaceTotal) }} / {{ probeSurfaceTotal }}</strong>
                                </v-progress-linear>
                            </v-tab-item>
                        </v-tabs>
                    </v-col>
                </v-row>
            </v-container>
        </v-card-text>
    </v-card>
</template>

<script lang="ts">
import BaseComponent from "../BaseComponent.vue";
import store from "@/store";

import { AxisLetter, Tool } from "@duet3d/objectmodel";

import { default as probeTypes, ProbeTypes, ProbeCommand, ProbeType, ProbeSettingsModifier, ProbeSettingModifier } from '../../types/Probe';

import { defineComponent } from 'vue';

export default defineComponent({
    extends: BaseComponent,

    data() {
        return {
            probeTypes: probeTypes as ProbeTypes,
            probeType: null as ProbeType | null,
            probeCommand: null as ProbeCommand | null,
            probing: false,
            aborting: false,
            tab: 0,
        };
    },
    computed: {
		allAxesHomed(): boolean { return store.state.machine.model.move.axes.every(axis => axis.visible && axis.homed)},
        workCoordinates(): Array<number> { return [...Array(9).keys()].map(i => i + 1); },
        probeActive(): boolean {
            return (this.currentTool?.number ?? -1) === (store.state.machine.model.global.get("mosPTID") ?? -2)
        },
        hasStatus(): boolean {
            return this.probePointTotal > 0 && this.probeSurfaceTotal > 0;
        },
        hasProbeTypeSelected(): boolean { return this.probeType !== null; },
        hasProbeCommand(): boolean { return this.probeCommand !== null; },
        probeRetryCurrent(): number {
            return (store.state.machine.model.global.get("mosPRRS") ?? 0);
        },
        probePointCurrent(): number {
            return (store.state.machine.model.global.get("mosPRPS") ?? 0);
        },
        probeSurfaceCurrent(): number {
            return (store.state.machine.model.global.get("mosPRSS") ?? 0);
        },
        probeRetryBuffer(): number {
            return Math.min((this.probeRetryCurrent + 1) / this.probeRetryTotal * 100, 100);
        },
        probePointBuffer(): number {
            return Math.min((this.probePointCurrent + 1) / this.probePointTotal * 100, 100);
        },
        probeSurfaceBuffer(): number {
            return Math.min((this.probeSurfaceCurrent + 1) / this.probeSurfaceTotal * 100, 100);
        },
        probeRetryTotal(): number {
            return store.state.machine.model.global.get("mosPRRT") ?? 0;
        },
        probePointTotal(): number {
            return store.state.machine.model.global.get("mosPRPT") ?? 0;
        },
        probeSurfaceTotal(): number {
            return store.state.machine.model.global.get("mosPRST") ?? 0;
        },
        probeRetryProgress(): number {
            return this.probeRetryCurrent / this.probeRetryTotal * 100;
        },
        probePointProgress(): number {
            return this.probePointCurrent / this.probePointTotal * 100;
        },
        probeSurfaceProgress(): number {
            return this.probeSurfaceCurrent / this.probeSurfaceTotal * 100;
        },
    },
    methods: {
        nextStep() {
            this.tab++;
        },
        async updateWorkplaceCoordinate() {
            let code;
            if (this.currentWorkplace < 7) {
                code = `G${53 + this.currentWorkplace}`;
            } else {
                code = `G59.${this.currentWorkplace - 6}`;
            }

            if (code) {
                await store.dispatch("machine/sendCode", `${code}\nG10 L20 P${this.currentWorkplace}`);
            }
        },
        selectProbeType(to: number) {
            if (to !== -1) {
                var probeType: ProbeType = this.probeTypes[to];
                this.probeType = probeType;
                this.probeCommand = new ProbeCommand(this.probeType.code, this.probeType.settings);
                this.nextStep();
            }
        },
        getProbeSummary(): string {
            if (!this.probeCommand) {
                return "";
            }

            return "";
        },
        getProbeCode(): string {
            if (!this.probeCommand) {
                return "";
            }

            // Get the GCode for the probe command based on the operator settings
            var mods = {
                [AxisLetter.Z]: {
                    numberValue: store.state.machine.model.move.axes.find(axis => axis.letter === AxisLetter.Z)?.machinePosition ?? 999,
                    sign: -1,
                } as ProbeSettingModifier
            } as ProbeSettingsModifier;

            const gcode: string[] = [
                this.probeCommand.toGCode(mods),
                // Add starting position
                `J${this.absolutePosition[AxisLetter.X]}`,
                `K${this.absolutePosition[AxisLetter.Y]}`,
                `L${this.absolutePosition[AxisLetter.Z]}`,
                `R0`, // Do not report probing results
            ];

            return gcode.join(" ");
        },
        async activateProbe() {
            this.probing = true;
            const ptID = this.probeTool?.number ?? -1;
            await store.dispatch("machine/sendCode", `T${ptID}`);
            this.probing = false;
            if(this.probeActive) {
                this.nextStep();
            }
        },
        async runProbe() {
            this.probing = true;
            await this.sendCode("M5012");
            this.nextStep();
            const reply = await this.sendCode(this.getProbeCode());

            if(reply.length > 0) {
                this.tab = (this.probeActive ? 1 : 0);
                this.probing = false;
            }

            await this.sendCode("M5012");
        },
    },
    mounted() {
        if(this.probeActive) {
            this.nextStep();
        }
    },
    watch: {
        probeActive(newVal: boolean, oldVal: boolean) {
            if(newVal && this.tab === 0) {
                this.nextStep();
            }
        },
        currentTool(newTool: (Tool | null), oldTool: (Tool | null)) {
            if(!this.probeActive) {
                this.tab = 0;
            } else if(this.tab === 0) {
                this.nextStep();
            }
        },
        hasStatus(newVal: boolean, oldVal: boolean) {
            if(oldVal && !newVal) {
                this.tab = (this.probeActive ? 1 : 0);
                this.probing = false;
            }
        },
    }
});

</script>
