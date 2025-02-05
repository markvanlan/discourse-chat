import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  @action
  closeSelf() {
    this.send("closeModal");
  },
});
