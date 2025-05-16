
<template>
	<v-card class="d-flex flex-column flex-grow-1">
		<v-card-title>
			<span>
				<v-icon small class="mr-1">mdi-file-code</v-icon>
        		{{ $t("plugins.millenniumos.panels.jobCode.cardTitle") }}
			</span>
		</v-card-title>

		<v-card-text>
			<code-stream>G0 X0 Y0 Z0</code-stream>
		</v-card-text>
	</v-card>
</template>

<script lang="ts">
import BaseComponent from "../BaseComponent.vue";

import store from "@/store";

import { defineComponent } from "vue";
export default defineComponent({
	extends: BaseComponent,
	computed: {
		code(): string { return "\nG0 X0 Y0 Z0\nG1 X10 Y10\nG1 X0"; },
		darkTheme(): boolean { return store.state.settings.darkTheme; },
		language(): string { return store.state.settings.language; },
	},
	data() {
		return {
			showAllLayers: false
		}
	},
	methods: {},
	mounted() {
		const that = this;
	},
	watch: {}
});
</script>