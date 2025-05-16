<template>
	<div>
		<v-row align="stretch" dense>
			<v-col cols="3" lg="4" md="5" order="1" order-lg="1" sm="5">
				<v-card class="justify-center fill-height">
					<v-card-title class="py-2 font-weight-bold">
						{{ $t("panel.status.caption") }}
						<v-spacer></v-spacer>
						<status-label v-if="status"></status-label>
					</v-card-title>
					<v-card-text>
						<template v-if="visibleAxes">
							<v-simple-table>
								<template v-slot:default>
									<tbody>
										<tr>
											<td><strong>{{ $t("plugins.millenniumos.panels.workplaceOrigins.workplaceHeader") }}</strong></td>
											<td align="right">
												<v-tooltip top>
													<template v-slot:activator="{ on, attrs }">
														<v-chip v-on="on" label outlined>
															{{ $workplaceAsGCode(currentWorkplace) }}
															<v-avatar right rounded :color="currentWorkplaceColor()">{{ currentWorkplace+1 }}</v-avatar>
														</v-chip>
													</template>
													<span>{{  currentWorkplaceText() }}</span>
												</v-tooltip>
											</td>
										</tr>
										<tr v-if="toolNumber !== null && toolName !== null">
											<td><strong>{{ $t("plugins.millenniumos.panels.cncStatus.toolName") }}</strong></td>
											<td align="right">
												<v-tooltip top>
													<template v-slot:activator="{ on, attrs }">
														<v-chip v-on="on" label outlined>
															{{ toolNameShort() }}
															<v-avatar right rounded class="green">{{ toolNumber }}</v-avatar>
														</v-chip>
													</template>
													<span>{{ toolName }}</span>
												</v-tooltip>
											</td>
										</tr>
										<tr v-if="toolRadius !== null">
											<td><strong>{{ $t("plugins.millenniumos.panels.cncStatus.toolRadius") }}</strong></td>
											<td align="right">
												<v-chip label outlined>
													{{ $display(toolRadius, 3, "mm") }}
													<v-avatar right rounded color="primary"><v-icon small>mdi-radius-outline</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>
										<tr v-if="toolOffset !== null">
											<td><strong>{{ $t("plugins.millenniumos.panels.cncStatus.toolOffset") }}</strong></td>
											<td align="right">
												<v-chip label outlined>
													{{ $display(toolOffset, 3, "mm") }}
													<v-avatar right rounded color="primary"><v-icon small>mdi-arrow-expand-vertical</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>
										<tr v-if="touchProbe !== null">
											<td><strong>{{ $t("plugins.millenniumos.panels.cncStatus.touchProbe") }}</strong></td>
											<td align="right">
												<v-chip label outlined >
													{{ (!touchProbeEnabled)? $t('plugins.millenniumos.panels.cncStatus.probeDisabled') : probeText(touchProbe) }}
													<v-avatar right rounded :color="(!touchProbeEnabled)? 'grey' : probeColor(touchProbe)">
														<v-icon small>{{ probeIcon(touchProbe) }}</v-icon>
													</v-avatar>
												</v-chip>
											</td>
										</tr>
										<tr v-if="toolsetter !== null">
											<td><strong>{{ $t("plugins.millenniumos.panels.cncStatus.toolsetter") }}</strong></td>
											<td align="right">
												<v-chip label outlined >
													{{ (!toolsetterEnabled)? $t('plugins.millenniumos.panels.cncStatus.probeDisabled') : probeText(toolsetter) }}
													<v-avatar right rounded :color="(!toolsetterEnabled)? 'grey' : probeColor(toolsetter)">
														<v-icon small>{{ probeIcon(toolsetter) }}</v-icon>
													</v-avatar>
												</v-chip>
											</td>
										</tr>
										<tr v-if="rotationCompensation !== 0">
											<td><strong>{{ $t("plugins.millenniumos.panels.cncStatus.rotationCompensation") }}</strong></td>
											<td align="right">
												<v-chip label outlined>
													{{ $display(rotationCompensation, 3, "°") }}
													<v-avatar right rounded color="primary"><v-icon small>mdi-restore</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>
									</tbody>
								</template>
							</v-simple-table>
						</template>
					</v-card-text>
				</v-card>
			</v-col>
			<v-col cols="12" lg="8" md="7" order="4" order-md="2" sm="8">
				<v-row align="stretch" class="fill-height">
					<v-col cols="12" lg="12">
						<mos-cnc-axes-position machinePosition class="fill-height" />
					</v-col>
					<v-col cols="12" lg="12">
						<mos-spindle-control-panel class="fill-height" />
					</v-col>
				</v-row>
			</v-col>
			<!--<v-col cols="5" lg="3" md="3" order="2" order-lg="3" sm="4">
				<v-card class="fill-height">
					<v-card-title class="py-2 font-weight-bold">
						{{ $t("panel.status.requestedSpeed") }}
					</v-card-title>
					<v-card-text>
						{{ $displayMoveSpeed(currentMove.requestedSpeed) }}
					</v-card-text>
				</v-card>
			</v-col>
			<v-col cols="4" lg="3" md="3" order="2" order-lg="4" sm="4">
				<v-card class="fill-height" order="5">
					<v-card-title class="py-2 font-weight-bold">
						{{ $t("panel.status.topSpeed") }}
					</v-card-title>
					<v-card-text>
						{{ $displayMoveSpeed(currentMove.topSpeed) }}
					</v-card-text>
				</v-card>
			</v-col>-->
		</v-row>
	</div>
</template>

<script lang="ts">
import BaseComponent from "../../BaseComponent.vue";

import { ProbeType, AnalogSensorType, Board, CurrentMove, Probe, AnalogSensor, Axis } from "@duet3d/objectmodel";

const enum WorkplaceSet {
	NONE,
	SOME,
	ALL
};

import store from "@/store";

import { isPrinting } from "@/utils/enums";
import { workplaceAsGCode } from "../../../utils/display";

import { defineComponent } from 'vue';

export default defineComponent({
    extends: BaseComponent,

	computed: {
		uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		status(): string { return store.state.machine.model.state.status; },
		currentMove(): CurrentMove { return store.state.machine.model.move.currentMove; },
		mainboard(): Board | undefined { return store.state.machine.model.boards.find(board => !board.canAddress); },
		probesPresent() { return store.state.machine.model.sensors.probes.some((probe) => probe && probe.type !== ProbeType.none); },
		probes(): Array<Probe | null> { return store.state.machine.model.sensors.probes; },
		sensorsPresent(): boolean { return (this.mainboard && ((this.mainboard.vIn !== null) || (this.mainboard.v12 !== null) || (this.mainboard.mcuTemp !== null))) || this.probesPresent; },
		analogSensors(): Array<AnalogSensor> {
			return store.state.machine.model.sensors.analog.filter((sensor) => (sensor !== null) && sensor.name && (sensor.type !== AnalogSensorType.unknown)) as Array<AnalogSensor>;
		},
		visibleAxes(): Array<Axis> {
			return store.state.machine.model.move.axes.filter(axis => axis.visible);
		},
		touchProbeEnabled(): boolean {
			return (
				store.state.machine.model.global.get('mosFeatTouchProbe') === true &&
				store.state.machine.model.global.get('mosTPID') !== null
			);
		},
		toolsetterEnabled(): boolean {
			return (
				store.state.machine.model.global.get('mosFeatToolSetter') === true &&
				store.state.machine.model.global.get('mosTSID') !== null
			);
		},
		touchProbe(): Probe | null {

			const mosTPID: number = store.state.machine.model.global.get('mosTPID') ?? null;
			if (mosTPID === null) {
				return null;
			}
			const p = store.state.machine.model.sensors.probes.at(mosTPID);
			return p ? p : null;
		},
		toolsetter(): Probe | null {
			const mosTSID: number = store.state.machine.model.global.get('mosTSID') ?? null;
			if (mosTSID === null) {
				return null;
			}
			const p = store.state.machine.model.sensors.probes.at(mosTSID);
			return p ? p : null;
		},
		toolNumber(): number | null {
			const t = store.state.machine.model.state.currentTool ?? -1;
			if ( t < 0 ) {
				return null;
			}
			return t;
		},
		toolName(): string | null {
			const t = store.state.machine.model.state.currentTool ?? -1;
			if ( t < 0 ) {
				return null;
			}
			return store.state.machine.model.tools.at(t)?.name ?? '';
		},
		toolRadius(): number | null {
			const t = store.state.machine.model.state.currentTool ?? -1;
			if ( t < 0 ) {
				return null;
			}
			return store.state.machine.model.global.get('mosTT').at(t).at(0) ?? -1;
		},
		toolOffset(): number | null {
			const t = store.state.machine.model.state.currentTool ?? -1;
			if ( t < 0 ) {
				return null;
			}
			// Return Z offset of tool (Axis 2)
			return store.state.machine.model.tools.at(t)?.offsets[2] ?? -1;
		},
		rotationCompensation(): number {
			return store.state.machine.model.move.rotation.angle;
		},
	},
	methods: {
		formatProbeValue(values: Array<number>) {
			if (values.length === 1) {
				return values[0];
			}
			return `${values[0]} (${values.slice(1).join(", ")})`;
		},
		probeSpanClasses(probe: Probe, index: number) {
			let result: Array<string> = [];
			if (index && store.state.machine.model.sensors.probes.length > 1) {
				result.push("ml-2");
			}
			if (!isPrinting(store.state.machine.model.state.status) && probe.value.length > 0) {
				if (probe.value[0] >= probe.threshold) {
					result.push("red");
					result.push(store.state.settings.darkTheme ? "darken-3" : "lighten-4");
				} else if (probe.value[0] > probe.threshold * 0.9) {
					result.push("orange");
					result.push(store.state.settings.darkTheme ? "darken-2" : "lighten-4");
				}
			}
			return result;
		},
		currentWorkplaceValid(): WorkplaceSet {
			const offsets = this.visibleAxes.map(axis => axis.workplaceOffsets[this.currentWorkplace]);

			if (offsets.every(offset => offset !== 0)) {
				return WorkplaceSet.ALL;
			}

			return offsets.some(offset => offset !== 0) ? WorkplaceSet.SOME : WorkplaceSet.NONE;
		},
		currentWorkplaceColor(): string {
			switch(this.currentWorkplaceValid()) {
				case WorkplaceSet.ALL:
					return 'success';
				case WorkplaceSet.SOME:
					return 'warning';
				default:
					return 'grey';
			}
		},
		currentWorkplaceText(): string {
			let translationString = "workplaceInvalid";
			switch(this.currentWorkplaceValid()) {
				case WorkplaceSet.ALL:
					translationString = "workplaceValid";
					break
				case WorkplaceSet.SOME:
					translationString = "workplacePartial";
					break
			}
			return this.$t(`plugins.millenniumos.panels.cncStatus.${translationString}`, [workplaceAsGCode(this.currentWorkplace)]).toString();
		},
		probeColor(probe: Probe) {
			return (probe.value[0] >= probe.threshold) ? 'red' : 'green';
		},
		probeText(probe: Probe) {
			return this.$t((probe.value[0] >= probe.threshold) ? 'plugins.millenniumos.panels.cncStatus.probeTriggered' : 'plugins.millenniumos.panels.cncStatus.probeNotTriggered', [probe.value[0]]);
		},
		probeIcon(probe: Probe) {
			return (probe.value[0] >= probe.threshold) ? 'mdi-bell-ring' : 'mdi-bell-sleep';
		},
		toolNameShort() {
			const toolName = this.toolName;
			if (toolName === null) {
				return '';
			}
			return toolName.length > 20 ? toolName.substring(0, 20) + '...' : toolName;
		},
	}
});
</script>
