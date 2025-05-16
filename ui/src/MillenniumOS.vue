<style scoped>
    .v-data-table >>> .v-data-table__wrapper > table > tbody > tr > td,
    .v-data-table >>> .v-data-table__wrapper > table > tbody > tr > th,
    .v-data-table >>> .v-data-table__wrapper > table > thead > tr > td,
    .v-data-table >>> .v-data-table__wrapper > table > thead > tr > th,
    .v-data-table >>> .v-data-table__wrapper > table > tfoot > tr > td,
    .v-data-table >>> .v-data-table__wrapper > table > tfoot > tr > th {
        padding: 0 4px;
    }

    .v-card__title {
        height: 70px;
    }

    .v-btn-toggle > .v-btn.v-btn {
        opacity: 1 !important;
    }

</style>
<template>
    <div class="mos mb-3">
        <!-- <v-row>
            <v-col cols="12">
                <mos-job-progress-panel class="mb-2" />
            </v-col>
        </v-row> -->

        <v-row>
            <v-col cols="8" class="pb-0">
                <mos-probing-panel class="mb-2 fill-height" />
            </v-col>
            <v-col cols="4" class="pb-0">
                <mos-workplace-origins-panel class="mb-2 fill-height" />
            </v-col>
        </v-row>
        <v-row>
            <!-- <v-col cols="12" lg="6" class="pb-0">
                <mos-probe-results-panel class="mb-2" />
            </v-col> -->
        </v-row>
	</div>
</template>

<script lang="ts">
export default {
    data: () => ({
        // nothing
    }),
    computed: {
        // nothing
    },
    methods: {
        // nothing
    },
};
</script>