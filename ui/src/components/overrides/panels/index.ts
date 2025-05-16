import Vue from "vue";

// Override default panels or components by importing
// them here and then registering them with the same
// name as the default component or panel.
import CNCContainerPanel from "./CNCContainerPanel.vue";
import CNCDashboardPanel from "./CNCDashboardPanel.vue";
import CNCMovementPanel from "./CNCMovementPanel.vue";

Vue.component("cnc-movement-panel", CNCMovementPanel);
Vue.component("cnc-container-panel", CNCContainerPanel);
Vue.component("cnc-dashboard-panel", CNCDashboardPanel);
