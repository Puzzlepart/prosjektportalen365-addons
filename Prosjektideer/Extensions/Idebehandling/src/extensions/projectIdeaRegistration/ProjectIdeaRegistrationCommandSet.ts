import { override } from "@microsoft/decorators";
import { Log } from "@microsoft/sp-core-library";
import {
  BaseListViewCommandSet,
  Command,
  IListViewCommandSetListViewUpdatedParameters,
  IListViewCommandSetExecuteEventParameters,
} from "@microsoft/sp-listview-extensibility";
import { Dialog } from "@microsoft/sp-dialog";
import { sp } from "@pnp/sp/presets/all";
import { DialogPrompt } from "./Components/Dialog";

import * as strings from "ProjectIdeaRegistrationCommandSetStrings";

const LOG_SOURCE: string = "ProjectIdeaRegistrationCommandSet";

export default class ProjectIdeaRegistrationCommandSet extends BaseListViewCommandSet<any> {
  @override
  public onInit(): Promise<void> {
    Log.info(LOG_SOURCE, "Initialized ProjectIdeaRegistrationCommandSet");
    return Promise.resolve();
  }

  @override
  public onListViewUpdated(
    event: IListViewCommandSetListViewUpdatedParameters
  ): void {
    const compareOneCommand: Command = this.tryGetCommand(
      "RECOMMENDATION_COMMAND"
    );
    if (compareOneCommand) {
      // This command should be hidden unless exactly one row is selected.
      compareOneCommand.visible = event.selectedRows.length === 1;
    }
  }

  @override
  public onExecute(event: IListViewCommandSetExecuteEventParameters): void {
    switch (event.itemId) {
      case "RECOMMENDATION_COMMAND":
        Dialog.prompt(event.selectedRows[0].getValueByName("Title"));
        break;
      default:
        throw new Error("Unknown command");
    }
  }
}
