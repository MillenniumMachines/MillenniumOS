<style scoped>
.axis-span {
	border-radius: 5px;
}

@media screen and (max-width: 600px) {
	.large-font-height {
		height: 35px;
	}

	.large-font {
		font-size: 30px;
	}
}

@media screen and (min-width: 601px) {
	.large-font-height {
		height: 55px;
	}

	.large-font {
		font-size: 50px;
	}
}
</style>

<template>
	<v-card class="py-0">
		<v-card-title class="py-2">
			<strong>
				{{ $t("plugins.millenniumos.panels.axesPosition.positionHeader") }}
			</strong>
		</v-card-title>
		<v-card-text class="pt-10">
			<v-row align-content="center" no-gutters class="">
				<v-col v-for="(axis, index) in visibleAxes" :key="axis.letter" class="d-flex flex-column align-center">
					<v-tooltip top>
						<template v-slot:activator="{ on, attrs }">
							<span v-on="on" class="axis-span large-font large-font-height pt-4" :class="axisSpanClasses(index)">
								{{ axis.letter }}
							</span>
						</template>
						<span>{{ axisTooltipText(index) }}</span>
					</v-tooltip>
					<v-tooltip top>
						<template v-slot:activator="{ on, attrs }">
							<div v-on="on" class="large-font large-font-height pt-4">
								{{ $displayAxisPosition(axis, false) }}
							</div>
						</template>
						<span>{{ $t('panel.status.toolPosition') }}</span>
					</v-tooltip>
					<v-tooltip v-if="machinePosition" top>
						<template v-slot:activator="{ on, attrs }">
							<div v-on="on" class="lighten-2">
								{{ $displayAxisPosition(axis, true) }}
							</div>
						</template>
						<span>{{ $t('panel.status.machinePosition') }}</span>
					</v-tooltip>
				</v-col>
			</v-row>
		</v-card-text>
	</v-card>
</template>

<script lang="ts">
import { Axis } from "@duet3d/objectmodel";
import BaseComponent from "../BaseComponent.vue";

import store from "@/store";

const enum AxisState {
	NONE,
	HOMED,
	AT_STOP
};

import { defineComponent } from "vue";

export default defineComponent({
	extends: BaseComponent,
	props: {
		machinePosition: {
			type: Boolean,
			required: true
		}
	},
	computed: {
		darkTheme(): boolean {
			return store.state.settings.darkTheme;
		},
		visibleAxes(): Array<Axis> {
			return store.state.machine.model.move.axes.filter(axis => axis.visible);
		}
	},
	methods: {
		axisState(axisIndex: number) : AxisState {
			const homed = store.state.machine.model.move.axes[axisIndex].homed;
			const atEndstop = axisIndex < store.state.machine.model.sensors.endstops.length && store.state.machine.model.sensors.endstops[axisIndex]?.triggered;
			return (homed ? (atEndstop) ? AxisState.AT_STOP : AxisState.HOMED : AxisState.NONE);
		},
		axisSpanClasses(axisIndex: number) {
			const classList: Array<string> = ['large-font-height', 'px-2'];
			classList.push(this.darkTheme ? "darken-3" : "lighten-4");
			if(axisIndex < 0) {
				return classList;
			}

			const state = this.axisState(axisIndex);

			switch(this.axisState(axisIndex)) {
				case AxisState.NONE:
					classList.push("grey");
					break;
				case AxisState.AT_STOP:
					classList.push("light-green");
					break;
			}
			return classList;
		},

		axisTooltipText(axisIndex: number): string {
			const axisLetter = this.visibleAxes[axisIndex].letter;
			let translationString = "notHomed";
			switch(this.axisState(axisIndex)) {
				case AxisState.HOMED:
					translationString = "homed";
					break
				case AxisState.AT_STOP:
					translationString = "atStop";
					break
			}
			return this.$t(`plugins.millenniumos.panels.axesPosition.${translationString}`, [axisLetter]).toString();
		}
	}
});
</script>

