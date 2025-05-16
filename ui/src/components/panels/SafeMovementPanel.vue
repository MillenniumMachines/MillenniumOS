<style>
/* .mos .move-control {
  flex-direction: column;
} */
</style>
<template>
    <v-card>
        <v-card-title class="pt-0">
            <v-icon small class="mr-1">mdi-bike-fast</v-icon>
            Safe Movement
        </v-card-title>
        <v-card-text>
            <v-container fluid>
                <v-row dense>
                    <v-col cols="1">
                    </v-col>
                    <v-col>
                        <v-row>
                            <v-col>
                                <v-btn-toggle
                                v-model="nextAxis"
                                borderless
                                mandatory
                                color="pink"
                                dense
                                >
                                    <v-btn
                                        v-for="(axis, index) in visibleAxes"
                                        large
                                    >
                                        <v-icon>mdi-alpha-{{ axis.letter.toLowerCase() }}-circle-outline</v-icon>
                                    </v-btn>
                                </v-btn-toggle>
                            </v-col>
                            <v-col align="center">
                                <v-btn x-large>
                                    <v-icon>mdi-arrow-left-bold</v-icon>
                                </v-btn>
                                <v-btn x-large>
                                    <v-icon>mdi-arrow-right-bold</v-icon>
                                </v-btn>
                            </v-col>
                        </v-row>
                    </v-col>
                    <v-col cols="3">
                        <v-slider

                        v-model="feedRate"
                        min="10"
                        max="100"
                        step="10"
                        thumb-label="always"
                        ticks
                        vertical
                        class="mx-4"
                        prepend-icon="mdi-speedometer-slow"
                        append-icon="mdi-speedometer"
                        >
                        <template v-slot:thumb-label>{{ feedRate }}%</template>
                        </v-slider>

                    </v-col>
                </v-row>
            </v-container>
        </v-card-text>
    </v-card>

</template>
<script lang="ts">
    import BaseComponent from "../BaseComponent.vue";
    import { Axis, AxisLetter, KinematicsName, MoveCompensationType } from "@duet3d/objectmodel";

    import store from "@/store";

    import { defineComponent } from 'vue';

    export default defineComponent({
        extends: BaseComponent,

        computed: {
            currentAxis(): string { return store.state.machine.model.move.axes[this.axis].letter; },
            currentAxisColor(): String { return this.axisColours[this.axis]; },
		    uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		    visibleAxes(): Array<Axis> { return store.state.machine.model.move.axes.filter(axis => axis.visible); },
		    allAxesHomed(): boolean { return store.state.machine.model.move.axes.every(axis => axis.visible && axis.homed)},
        },
        data() {
            return {
                feedRate: 100,
                axis: 0,
                axisColours: ["pink", "lime", "orange", "purple", "cyan", "brown", "teal", "amber"],
            }
        },
        methods: {
            nextAxis() {
                this.axis = (this.axis + 1) % this.visibleAxes.length;
            },
        }
    });
</script>