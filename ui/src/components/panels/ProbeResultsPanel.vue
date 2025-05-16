<style scoped>
.v-card .probeType {
    min-height: 200px;
}
</style>
<template>
    <v-card>
        <v-card-title>Probe Results</v-card-title>
        <v-container fluid>
            <v-row>
                <v-col cols="12">
                    <v-data-table
                        disable-filtering
                        disable-pagination
                        disable-sort
                        hide-default-footer
                        show-select
                        :headers="headers"
                        :items="items"
                    >

                        <template v-for="(axis, index) in visibleAxes" v-slot:[`item.${axis.letter}`]="{ item }">
                            <div :key="axis.letter">
                                {{ item[axis.letter] }}<v-icon>mdi-arrow-right-bold</v-icon>
                            </div>
                        </template>

                        <template v-slot:item.actions="{ item }">
                            <v-btn
                                icon
                                :disabled="uiFrozen || !allAxesHomed"
                            >
                                <v-icon>mdi-cursor-default</v-icon>
                            </v-btn>
                        </template>

                    </v-data-table>
                </v-col>
            </v-row>
            <v-row>
                <v-col cols="12" class="d-flex justify-center">
                    <v-btn
                        x-large
                        color="primary"
                    >Probe</v-btn>
                </v-col>
            </v-row>
        </v-container>
    </v-card>
</template>
<script lang="ts">
    import BaseComponent from "../BaseComponent.vue";
    import { Axis } from "@duet3d/objectmodel";

    function randomInt(min: number, max: number): number {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    import store from "@/store";

    import { defineComponent } from 'vue';

    export default defineComponent({
        extends: BaseComponent,

        props: {},
        computed: {
            currentWorkplace(): number { return store.state.machine.model.move.workplaceNumber; },
		    uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		    allAxesHomed(): boolean { return store.state.machine.model.move.axes.every(axis => axis.visible && axis.homed)},
            visibleAxes(): Array<Axis> {
                return store.state.machine.model.move.axes.filter(axis => axis.visible);
            }
        },
        data() {

            // Headers has static items at the start and end, and
            // dynamic items representing each axis in the middle.
            let headers: any = [];

           headers = headers.concat(store.state.machine.model.move.axes.map(axis => ({
                text: axis.letter,
                value: axis.letter,
                align: 'center',
            })));

            headers.push({
                text: 'Actions',
                value: 'actions',
                align: 'end',
            });

            let items: any = [];
            const workplaces = store.state.machine.model.limits?.workplaces ?? 0;
            for (let w = 0; w < workplaces; w++) {
                let workplace: any = {
                    'index': w
                };
                store.state.machine.model.move.axes.forEach(axis => {
                    workplace[axis.letter] = randomInt(0, 100);
                });
                items.push(workplace);
            }
            return {
                headers: headers,
                items: items,
            }
        },
        methods: {
        }
    });
</script>
