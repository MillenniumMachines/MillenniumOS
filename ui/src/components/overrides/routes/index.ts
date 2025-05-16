import Vue, { VueConstructor, ComponentPublicInstance, DefineComponent } from "vue";
import { default as VueRouter } from "@/routes";
import OriginalJobStatus from "@/routes/Job/Status.vue";
import JobStatus from "./Job/Status.vue";

// List of original => new components to override
const overrides: [VueConstructor<Vue>, DefineComponent<any, any, any, any>][] = [
    [OriginalJobStatus, JobStatus as DefineComponent<any, any, any, any>]
];

// Override routes with the new component.
VueRouter.beforeEach((to, _, next) => {
    overrides.forEach(([original, replacement]) => {
        if (to.matched[0].components.default === original) {
            to.matched[0].components.default = replacement;
        }
    });
    next();
});