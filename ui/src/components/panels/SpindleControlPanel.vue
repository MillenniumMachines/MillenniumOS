<template>
	<v-card class="justify-center fill-height">
		<v-card-title class="py-2 font-weight-bold">
			Spindles
		</v-card-title>
		<v-card-text>
			<v-simple-table>
				<template v-slot:default>
					<tbody>
						<tr v-for="(spindle, index) in configuredSpindles">
							<td><strong>Spindle #{{ index+1 }}</strong></td>
							<td align="right">
								<v-chip label outlined>
									{{ spindle.current }}RPM
									<v-avatar right rounded class="green">
										<v-icon small>{{ spindleIcon(spindle) }}</v-icon>
									</v-avatar>
								</v-chip>
							</td>
						</tr>
					</tbody>
				</template>
			</v-simple-table>
		</v-card-text>
	</v-card>
</template>

<script lang="ts">
import BaseComponent from "../BaseComponent.vue";

import { Spindle } from "@duet3d/objectmodel";

import store from "@/store";

import { defineComponent } from 'vue';

export default defineComponent({
    extends: BaseComponent,

	computed: {
		uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		configuredSpindles(): Array<Spindle> {
			return store.state.machine.model.spindles.filter((spindle: Spindle | null): spindle is Spindle => spindle !== null && spindle?.state != "unconfigured");
		},
	},
	methods: {
		spindleIcon(spindle: Spindle) {
			if(spindle.current === null) return 'mdi-help';
			return (spindle.current > 0) ? 'mdi-axis-z-rotate-clockwise' : (spindle.current < 0) ? 'mdi-axis-z-rotate-counterclockwise' : 'mdi-pause';
		}
	}
});
</script>
