<template>
    <v-card>
        <v-card-text>
            <v-container fluid>
                <v-row>
                    <v-col>
                            <v-stepper>
                                <v-stepper-header>
                                <v-stepper-step v-for="(step, k) in steps" :key="k" :step="k">{{ step.title }}</v-stepper-step>
                                </v-stepper-header>
                            </v-stepper>
                    </v-col>
                </v-row>
            </v-container>
        </v-card-text>
    </v-card>
</template>

<script lang="ts">
import BaseComponent from "../BaseComponent.vue";

// Steps should be loaded from the store.
import { defineComponent } from 'vue';

export default defineComponent({
    extends: BaseComponent,

    data() {
        return {
            steps: [
                { title: "Run Job", done: false },
                { title: "Probe Origin in G54", done: false },
                { title: "Insert 6mm 1-Flute Endmill", done: false },
                { title: "Review", done: false },
                { title: "Face top surface", done: false },
            ],
        };
    },
    computed: {
    },
    methods: {},
    mounted() {},
    watch: {},
});

</script>
