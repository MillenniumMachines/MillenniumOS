import Vue from "vue";

export const workplaceAsGCode = function(workplace: number): string {
    return 'G' + ((workplace < 6) ? 54 + workplace : 59 + ((workplace % 5) * 0.1)).toString();
}

// Register display extensions
Vue.prototype.$workplaceAsGCode = workplaceAsGCode;