<style scoped>
    .v-data-table >>> .v-data-table__wrapper > table > tbody > tr > td,
    .v-data-table >>> .v-data-table__wrapper > table > tbody > tr > th,
    .v-data-table >>> .v-data-table__wrapper > table > thead > tr > td,
    .v-data-table >>> .v-data-table__wrapper > table > thead > tr > th,
    .v-data-table >>> .v-data-table__wrapper > table > tfoot > tr > td,
    .v-data-table >>> .v-data-table__wrapper > table > tfoot > tr > th {
    padding: 0 8px;
    }
</style>
<template>
    <v-card>
        <v-card-title>{{ $t("plugins.millenniumos.panels.workplaceOrigins.cardTitle") }}</v-card-title>
        <v-container fluid>
            <v-row>
                <v-col>
                    <v-data-table
                        dense
                        disable-filtering
                        disable-pagination
                        disable-sort
                        hide-default-footer
                        mobile-breakpoint="0"
                        class="text-body-2 px-2"
                        :headers="headers"
                        :items="items"
                        :item-class="workplaceItemClass"
                        item-key="offset"
                        @click:row="selectWorkplace"
                    >
                        <template v-for="(axis, index) in visibleAxes" v-slot:[`item.${axis.letter}`]="{ item }">
                            <mos-axis-input
                                :key="index+1"
                                :axis="axis"
                                :workplaceOffset="item.offset"
                            ></mos-axis-input>
                        </template>
                        <template v-slot:item.active="{ item }">
                            <v-tooltip top>
                                <template v-slot:activator="{ on, attrs }">
                                    <v-btn
                                        icon
                                        v-bind="attrs"
                                        v-on="on"
                                        :disabled="uiFrozen"
                                        :loading="item.switching"
                                    >
                                        <v-icon
                                            :color="item.offset == currentWorkplace ? 'success' : 'error'"
                                            :disabled="uiFrozen"
                                            @click.stop="switchWorkplace(item)"
                                        >
                                            {{ item.offset == currentWorkplace ? 'mdi-checkbox-marked' : 'mdi-checkbox-blank-outline' }}
                                        </v-icon>
                                    </v-btn>
                                </template>
                                <span>Activate workplace {{ item.workplace }}</span>
                            </v-tooltip>
                        </template>
                        <template v-slot:item.actions="{ item }">
                            <v-container fluid py-1 px-1>
                                <v-row>
                                    <v-col cols="12" lg="12">
                                        <v-tooltip top>
                                            <template v-slot:activator="{ on, attrs }">
                                                <v-btn
                                                    icon
                                                    v-bind="attrs"
                                                    v-on="on"
                                                    :disabled="uiFrozen"
                                                    :loading="item.clearing"
                                                >
                                                    <v-icon small @click="clearWorkplace(item)">mdi-cancel</v-icon>
                                                </v-btn>
                                            </template>
                                            <span>{{ $t("plugins.millenniumos.panels.workplaceOrigins.resetAction", [item.workplace]) }}</span>
                                        </v-tooltip>
                                    </v-col>
                                </v-row>
                            </v-container>
                        </template>
                    </v-data-table>
                </v-col>
            </v-row>
        </v-container>
    </v-card>
</template>
<script lang="ts">
    import BaseComponent from "../BaseComponent.vue";
    import { Axis } from "@duet3d/objectmodel";

    import store from "@/store";
    import { workplaceAsGCode } from "../../utils/display";

    import { defineComponent } from 'vue';

    export default defineComponent({
        extends: BaseComponent,
        props: {},
        computed: {
		    uiFrozen(): boolean { return store.getters["uiFrozen"]; },
		    allAxesHomed(): boolean { return store.state.machine.model.move.axes.every(axis => axis.visible && axis.homed)},
            visibleAxes(): Array<Axis> {
                return store.state.machine.model.move.axes.filter(axis => axis.visible);
            },
            visibleAxesLetters(): Array<string> {
                return this.visibleAxes.map(axis => axis.letter);
            },
            axisHeaders(): Array<any> {
                return this.visibleAxes.map(axis => ({
                    text: axis.letter,
                    value: axis.letter,
                    align: 'center',
                }));
            },
            headers(): Array<any> {
                return this.headersPrepend.concat(this.axisHeaders, this.headersAppend);
            },
            items(): Array<any> {
                const workplaces = store.state.machine.model.limits?.workplaces ?? 0;
                return Array.from({ length: workplaces }, (_, w) => {
                    const code = workplaceAsGCode(w);
                    const workplace: any = {
                        'workplace': `${w+1} (${code})`,
                        'code': code,
                        'loading': false,
                        'offset': w,
                    };
                    store.state.machine.model.move.axes.forEach(axis => {
                        workplace[axis.letter] = axis.workplaceOffsets[w];
                    });
                    return workplace;
                });
            }
        },
        data() {
            return {
                selectedWorkplace: -1,
                headersPrepend: [{
                    text: 'Workplace',
                    value: 'workplace',
                    align: 'start',
                },{
                    text: this.$t('plugins.millenniumos.panels.workplaceOrigins.activeHeader'),
                    value: 'active',
                    align: 'center',
                }],
                headersAppend: [{
                    text: '',
                    value: 'actions',
                    align: 'end',
                }],
            }
        },
        methods: {
            // Selected workplace should be lighter than current
            // Active workplace should be green
            // Active and selected workplace should be darker than
            // active workplace.
            workplaceItemClass(item: any) {
                return (item.offset == this.selectedWorkplace) ? 'primary' : '';
            },
            selectWorkplace(item: any) {
                if(this.selectedWorkplace === item.offset) {
                    this.selectedWorkplace = -1;
                } else {
                    this.selectedWorkplace = item.offset;
                }
            },
            async updateItem(item: any, stateName: string, code: string | null = null) {
                this.$set(item, stateName, true);
                await this.sendCode(code ?? item.code);
                this.$set(item, stateName, false);
            },
            async switchWorkplace(item: any) {
                this.updateItem(item, 'switching');
            },
            async clearWorkplace(item: any) {
                const axisStrings = this.visibleAxesLetters.map(axis => axis + "0").join(" ");
                this.updateItem(item, 'clearing', `G10 L2 P${item.offset+1} ${axisStrings}`);
            }
        }
    });
</script>
