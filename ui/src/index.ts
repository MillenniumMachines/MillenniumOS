'use strict';

import { registerRoute } from "@/routes";
import { registerPluginLocalization } from "@/i18n";
import { registerPluginData, PluginDataType } from '@/store';

import './utils';

import './components/inputs';
import './components/panels';
import './components/overrides';

import Dash from './MillenniumOS.vue'

import en from "./i18n/en.json";

registerPluginLocalization("millenniumos", "en", en);

// Register a route via Settings -> Object Model
registerRoute(Dash, {
	Control: {
		MillenniumOS: {
			icon: "mdi-toolbox",
			caption: "plugins.millenniumos.menuCaption",
			path: "/Plugins/MillenniumOS"
		}
	}
});

registerPluginData('MillenniumOS', PluginDataType.machineCache, 'protectedMoveProbeID', -1);
