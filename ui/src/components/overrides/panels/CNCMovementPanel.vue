<style scoped>
.move-btn {
	padding-left: 0px !important;
	padding-right: 0px !important;
	min-width: 0;
	height: 65px !important;
}

.wcs-selection {
	max-width: 200px;
}
</style>

<template>
	<v-card>
		<v-card-title class="pt-0">
			<v-icon small class="mr-1">mdi-swap-horizontal</v-icon>
			{{ $t("panel.movement.caption") }}
			<v-spacer />
			<v-select v-model="currentWorkplace" :items="workCoordinates" class="wcs-selection"
					  hint="Work Coordinate System" @change="updateWorkplaceCoordinate" persistent-hint />
		</v-card-title>
		<v-card-text v-show="visibleAxes.length">
			<v-row dense>
				<v-col cols="6" order="1" md="2" order-md="1">
					<code-btn block v-show="visibleAxes.length" color="primary" code="G28"
							  :title="$t('button.home.titleAll')" class="ml-0 move-btn">
						{{ $t("button.home.captionAll") }}
					</code-btn>
				</v-col>
				<v-col cols="6" order="2" md="8" order-md="2">
					<v-menu offset-y left :disabled="uiFrozen">
						<template #activator="{ on }">
							<v-btn v-show="visibleAxes.length" :color="isProtectedMovesEnabled ? 'primary' : 'warning'" block class="mx-0 move-btn"
								   :disabled="uiFrozen" v-on="on">
								{{ (isProtectedMovesEnabled) ? $t("plugins.millenniumos.panels.cncMovement.protectionState.enabled", [protectedMoveProbeID]) : $t("plugins.millenniumos.panels.cncMovement.protectionState.disabled") }}
								<v-icon>mdi-menu-down</v-icon>
							</v-btn>
						</template>

						<v-card>
							<v-list>
								<v-list-item v-if="protectedMoveProbes.length == 1">
									<v-icon class="mr-1">mdi-alert-octagon-outline</v-icon>
									{{ $t("plugins.millenniumos.panels.cncMovement.protectionProbeNone") }}
								</v-list-item>
								<template v-if="protectedMoveProbes.length > 1">
									<v-list-item
										v-for="probe in protectedMoveProbes"
										:key="probe.id"
										v-if="probe.id !== protectedMoveProbeID"
										@click="protectedMoveProbeID = probe.id">
										<v-icon class="mr-1">{{ probe.id === -1 ? 'mdi-alert-octagon-outline': 'mdi-target-variant' }}</v-icon>
										{{ probe.description }}
									</v-list-item>

								</template>
							</v-list>
						</v-card>
					</v-menu>
				</v-col>
				<v-col cols="12" order="3" md="2" order-md="3">
					<v-btn @click="setWorkplaceZero" block class="move-btn">
						{{ $t("panel.movement.setWorkXYZ") }}
					</v-btn>
				</v-col>
			</v-row>

			<v-row v-for="(axis, axisIndex) in visibleAxes" :key="axisIndex" dense>
				<!-- Regular home buttons -->
				<v-col cols="2" order="1" sm="4" md="1" order-md="1">
					<v-row dense>
						<v-col>
							<code-btn tile block :color="axis.homed ? 'primary' : 'warning'" :disabled="uiFrozen"
									  :title="$t('button.home.title', [/[a-z]/.test(axis.letter) ? `'${axis.letter}` : axis.letter])"
									  :code="`G28 ${/[a-z]/.test(axis.letter) ? '\'' : ''}${axis.letter}`" class="move-btn">
								{{ $t("button.home.caption", [axis.letter]) }}
							</code-btn>
						</v-col>
					</v-row>
				</v-col>

				<!-- Decreasing movements -->
				<v-col cols="6" order="3" md="5" order-md="2">
					<v-row dense>
						<v-col v-for="index in numMoveSteps" :key="index" :class="getMoveCellClass(index - 1)">
							<v-btn @click="sendMoveCode(axis, index-1, true)" no-wait
									  @contextmenu.prevent="showMoveStepDialog(axis.letter, index - 1)" block tile
									  class="move-btn">
								<v-icon>mdi-chevron-left</v-icon>
								{{ axis.letter + showSign(-moveSteps(axis.letter)[index - 1]) }}
							</v-btn>
						</v-col>
					</v-row>
				</v-col>

				<!-- Increasing movements -->
				<v-col cols="6" order="4" md="5" order-md="3">
					<v-row dense>
						<v-col v-for="index in numMoveSteps" :key="index" :class="getMoveCellClass(numMoveSteps - index)">
							<v-btn @click="sendMoveCode(axis, numMoveSteps - index, false)" no-wait
									  @contextmenu.prevent="showMoveStepDialog(axis.letter, numMoveSteps - index)" block
									  tile class="move-btn">
								{{ axis.letter + showSign(moveSteps(axis.letter)[numMoveSteps - index]) }}
								<v-icon>mdi-chevron-right</v-icon>
							</v-btn>
						</v-col>
					</v-row>
				</v-col>

				<!-- Set axis-->
				<v-col cols="2" order="2" offset="8" sm="4" offset-sm="4" md="1" order-md="4" offset-md="0">
					<v-row dense>
						<v-col>
							<code-btn color="warning" tile block :code="`G10 L20 P${currentWorkplace} ${axis.letter}0`"
									  class="move-btn">
								{{ $t("panel.movement.set", [axis.letter]) }}
							</code-btn>
						</v-col>
					</v-row>
				</v-col>
			</v-row>

			<v-row dense>
				<v-col>
					<v-btn color="warning" @click="goToWorkplaceZero" tile block class="move-btn">
						{{ $t("panel.movement.workzero") }}
					</v-btn>
				</v-col>
			</v-row>
		</v-card-text>

		<v-alert :value="unhomedAxes.length !== 0" type="warning" class="mb-0">
			{{ $tc("panel.movement.axesNotHomed", unhomedAxes.length) }}
			<strong>
				{{ unhomedAxes.map(axis => axis.letter).join(", ") }}
			</strong>
		</v-alert>
		<v-alert :value="visibleAxes.length === 0" type="info">
			{{ $t("panel.movement.noAxes") }}
		</v-alert>

		<input-dialog :shown.sync="moveStepDialog.shown" :title="$t('dialog.changeMoveStep.title')"
					  :prompt="$t('dialog.changeMoveStep.prompt')" :preset="moveStepDialog.preset" is-numeric-value
					  @confirmed="moveStepDialogConfirmed" />
	</v-card>
</template>

<script lang="ts">
import { Axis, AxisLetter, Probe } from "@duet3d/objectmodel";
import Vue from "vue";

import { MachineCache } from "../../../types/MachineCache"

import { log, LogType } from "@/utils/logging";

import store from "@/store";

import { setPluginData, PluginDataType } from '@/store';

import { ProbeType } from "@duet3d/objectmodel";

type ProtectedMoveProbe = {
	id: number;
	description: string;
};


export default Vue.extend({
	computed: {
        pluginCache(): MachineCache { return store.state.machine.cache.plugins.MillenniumOS as MachineCache; },
		uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		moveSteps(): (axisLetter: AxisLetter) => Array<number> { return ((axisLetter: AxisLetter) => store.getters["machine/settings/moveSteps"](axisLetter)); },
		numMoveSteps(): number { return store.getters["machine/settings/numMoveSteps"]; },
		visibleAxes(): Array<Axis> { return store.state.machine.model.move.axes.filter(axis => axis.visible); },
		unhomedAxes(): Array<Axis> { return store.state.machine.model.move.axes.filter(axis => axis.visible && !axis.homed); },
		workCoordinates(): Array<number> { return [...Array(9).keys()].map(i => i + 1); },
		workplaceNumber(): number { return store.state.machine.model.move.workplaceNumber; },
		protectedMoveProbeID: {
			get(): number {
			    if(this.currentProtectedMoveProbeID === -1) {
                    const cachedProbeID = this.pluginCache.protectedMoveProbeID;
                    if(store.state.machine.model.sensors.probes[cachedProbeID] !== null) {
                        this.currentProtectedMoveProbeID = cachedProbeID;
                    }
                }
				return this.currentProtectedMoveProbeID
			},
			set(value: number) {
              this.currentProtectedMoveProbeID = value;
              setPluginData('MillenniumOS', PluginDataType.machineCache, 'protectedMoveProbeID', value);
			}
		},
		isProtectedMovesEnabled(): boolean { return this.protectedMoveProbeID >= 0; },
		protectedMoveProbes: {
			get(): Array<ProtectedMoveProbe> {
				const probes: Array<ProtectedMoveProbe> = [];

				// Enumerate probes
				store.state.machine.model.sensors.probes.map((probe, index) => {
					if (probe !== null && [ProbeType.digital, ProbeType.unfilteredDigital, ProbeType.blTouch].includes(probe.type)) {
						probes.push({
							id: index,
							description: this.$t('plugins.millenniumos.panels.cncMovement.protectionProbeDescription', [index, ProbeType[probe.type], probe.travelSpeed, "mm/min"]).toString()
						});
					}
				});
				probes.push({
					id: -1,
					description: this.$t('plugins.millenniumos.panels.cncMovement.protectionProbeDisable', [store.state.machine.settings.moveFeedrate, "mm/min"]).toString()
				});
				return probes;
			}
		}

	},
	data() {
		return {
			moveStepDialog: {
				shown: false,
				axis: AxisLetter.X,
				index: 0,
				preset: 0
			},
			currentWorkplace: 0,
			currentProtectedMoveProbeID: -1,
		};
	},
	methods: {
		getMoveStep(axis: Axis, index: number): number {
			return this.moveSteps(axis.letter)[index];
		},
		getMoveCellClass(index: number) {
			let classes = "";
			if (index === 0 || index === 5) {
				classes += "hidden-lg-and-down";
			}
			if (index > 1 && index < 4 && index % 2 === 1) {
				classes += "hidden-md-and-down";
			}
			return classes;
		},
		getProtectedMoveCode(axis: Axis, position: number): string {
			// G38.3 probe moves do not check axis limits, and they are always
			// absolute moves. We need to check the limits ourselves, and calculate
			// the absolute position of the target.

			// Probe is always valid
			const probe = store.state.machine.model.sensors.probes[this.protectedMoveProbeID] as Probe;

			return `M120\nG90\nG53 G38.3 K${this.protectedMoveProbeID} F${probe.travelSpeed} ${/[a-z]/.test(axis.letter) ? '\'' : ""}${axis.letter}${position}\nM121`;

		},
		async sendMoveCode(axis: Axis, index: number, decrementing: boolean) {
			let distance = this.getMoveStep(axis, index);
			if(decrementing) {
				distance = -distance;
			}

			const feedRate = store.state.machine.settings.moveFeedrate;

			// Validate move target
			const targetPos = (axis.machinePosition as number) + distance;

			if(targetPos < axis.min || targetPos > axis.max) {
            	log(LogType.error, "Move Error", `Target ${axis.letter}=${this.$display(targetPos, 1)} is out of bounds!`);
				return;
			}

			if(!this.isProtectedMovesEnabled) {
				return await this.sendCode(`M120\nG91\nG1 F${feedRate} ${/[a-z]/.test(axis.letter) ? '\'' : ""}${axis.letter}${distance}\nM121`);
			}

			// Validate probe configuration
			const probe = store.state.machine.model.sensors.probes[this.protectedMoveProbeID] as Probe;

			if(probe === null) {
            	return log(LogType.error, "Protected Move Error", `Probe ${this.protectedMoveProbeID} is not configured!`);
			}

			// We allow the Z axis to move in a positive direction
			// if the probe is triggered because there should be
			// no obstructions above the probe.
			if(axis.letter === AxisLetter.Z && !decrementing) {
				return await this.sendCode(`M120\nG91\nG1 F${probe.travelSpeed} ${/[a-z]/.test(axis.letter) ? '\'' : ""}${axis.letter}${distance}\nM121`);
			}

			// Do not allow probe to move if already triggered.
			if(probe.value[0] >= probe.threshold)  {
				return log(LogType.error, "Protected Move Error", `Probe ${this.protectedMoveProbeID} is already triggered!`);
			}

			return await this.sendCode(this.getProtectedMoveCode(axis, targetPos));

		},
		showSign: (value: number) => (value > 0 ? `+${value}` : value),
		showMoveStepDialog(axis: AxisLetter, index: number) {
			this.moveStepDialog.axis = axis;
			this.moveStepDialog.index = index;
			this.moveStepDialog.preset = this.moveSteps(this.moveStepDialog.axis)[this.moveStepDialog.index];
			this.moveStepDialog.shown = true;
		},
		moveStepDialogConfirmed(value: number) {
			store.commit("machine/settings/setMoveStep", {
				axis: this.moveStepDialog.axis,
				index: this.moveStepDialog.index,
				value
			});
		},
		async sendCode(code: string) {
			await store.dispatch("machine/sendCode", code);
		},
		async setWorkplaceZero() {
			let code = `G10 L20 P${this.currentWorkplace}`;
			this.visibleAxes.forEach(axis => (code += ` ${axis.letter}0`));
			await store.dispatch("machine/sendCode", `${code}\nG10 L20 P${this.currentWorkplace}`);
		},
		async goToWorkplaceZero() {
			await store.dispatch("machine/sendCode", 'M98 P"workzero.g"');
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
	},
	mounted() {
		this.currentWorkplace = this.workplaceNumber + 1;
	},
	watch: {
		isConnected() {
			// Hide dialogs when the connection is interrupted
			this.moveStepDialog.shown = false;
		},
		workplaceNumber(to: number) {
			this.currentWorkplace = to + 1;
		}
	},
});
</script>
