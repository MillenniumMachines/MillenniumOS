<template>
    <v-text-field
        dense
        v-model="coord"
        :disabled="uiFrozen"
        color="warning"
        :loading="loading"
        @change="setCoordinate"
        type="number"
        step="0.001"
        hide-details
        class="text-body-2 mt-0"
    >
        <template v-slot:append>
            <v-tooltip top
            open-on-click
            :open-on-hover="false"
            >
                <template v-slot:activator="{ on, attrs }">
                    <v-icon
                        mt-8
                        small
                        v-visible="hasError"
                        v-bind="attrs"
                        v-on="on"
                        color="error"
                        class="mt-1"
                        >mdi-alert-box</v-icon>
                </template>
                <span>{{ errorMsg }}</span>
            </v-tooltip>
        </template>
    </v-text-field>
</template>
<script lang="ts">
    import Vue from "vue";
    import BaseComponent from "../BaseComponent.vue";
    import { Axis } from "@duet3d/objectmodel";

    import store from "@/store";

    Vue.directive('visible', function(el, binding) {
        el.style.visibility = !!binding.value ? 'visible' : 'hidden';
        el.style.opacity = !!binding.value ? '1' : '0';
        el.style.cssText += 'transition: visibility 0.3s linear, opacity 0.3s linear;'
    });


    import { defineComponent } from 'vue';

    export default defineComponent({
        extends: BaseComponent,
        props: {
            axis: {
                type: Axis,
                required: true,
            },
            workplaceOffset: {
                type: Number,
                required: true,
            }
        },
        computed: {
		    uiFrozen(): Boolean { return store.getters["uiFrozen"]; },
            hasError(): Boolean { return this.errorMsg !== ""; },
            coord: {
                get(): string {
                    return this.axis.workplaceOffsets[this.workplaceOffset].toFixed(3);
                },
                set(value: string) {
                    const num = parseFloat(value);
                    if (isNaN(num)) {
                        this.errorMsg = "Invalid number";
                        return;
                    }

                    if (num < this.axis.min || num > this.axis.max) {
                        this.errorMsg =  `Value must be between ${this.axis.min} and ${this.axis.max}`;
                        return;
                    }

                    this.errorMsg = "";
                    this.pendingValue = num;
                }
            }
        },
        data() {
            return {
                loading: false,
                errorMsg: "",
                pendingValue: 0,
            }
        },
        methods: {
            setCoordinate: async function () {
                if(this.hasError || this.pendingValue === this.axis.workplaceOffsets[this.workplaceOffset]) {
                    return;
                }
                this.loading = true;
                await this.sendCode(`G10 L2 P${this.workplaceOffset+1} ${this.axis.letter}${this.pendingValue}`);
                this.loading = false;
            },
        }
    });
</script>
