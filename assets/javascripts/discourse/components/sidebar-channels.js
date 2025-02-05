import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";

export default Component.extend({
  tagName: "",
  toggleSection: null,
  chat: service(),
  router: service(),

  show: false,
  fetchedChannels: false,

  init() {
    this._super(...arguments);

    if (!this.chat.userCanChat) {
      return;
    }
    this.appEvents.on("chat:refresh-channels", this, "fetchChannels");

    withPluginApi("0.12.1", (api) => {
      api.onPageChange(() => {
        this.calcShouldShow();
      });
    });
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents.off("chat:refresh-channels", this, "fetchChannels");
  },

  calcShouldShow() {
    this.set(
      "show",
      !this.currentUser.chat_isolated ||
        this.chat.isChatPage ||
        this.chat.isBrowsePage
    );
    if (this.show && !this.fetchedChannels) {
      this.fetchChannels();
    }
  },

  @action
  fetchChannels() {
    this.chat.getChannels().then(() => {
      this.set("fetchedChannels", true);
    });
  },

  @action
  switchChannel(channel) {
    if (
      this.site.mobileView ||
      this.router.currentRouteName.startsWith("chat.")
    ) {
      this.router.transitionTo("chat.channel", channel.id, channel.title);
    } else {
      this.appEvents.trigger("chat:open-channel", channel);
    }
    return false;
  },
});
