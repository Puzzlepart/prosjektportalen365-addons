import { override } from "@microsoft/decorators";
import { Log } from "@microsoft/sp-core-library";
import {
  BaseListViewCommandSet,
  Command,
  IListViewCommandSetListViewUpdatedParameters,
  IListViewCommandSetExecuteEventParameters,
  RowAccessor,
} from "@microsoft/sp-listview-extensibility";
import { Dialog } from "@microsoft/sp-dialog";
import { sp } from "@pnp/sp/presets/all";
import DialogPrompt from "./Components/Dialog";
import { ConsoleListener, Logger, LogLevel } from "@pnp/logging";

Logger.subscribe(new ConsoleListener());
const LOG_SOURCE: string = "ProjectDataCommandSet";

enum RecommendationType {
  Accepted = "Godkjent for konseptutredning",
  Consideration = "Under vurdering",
  Declined = "Avvist",
}

export default class ProjectDataCommandSet extends BaseListViewCommandSet<any> {
  private userAuthorized: boolean;

  @override
  public async onInit(): Promise<void> {
    Log.info(LOG_SOURCE, "Initialized ProjectDataCommandSet");
    this.userAuthorized = await this.isUserAuthorized();

    return Promise.resolve();
  }

  @override
  public async onListViewUpdated(
    event: IListViewCommandSetListViewUpdatedParameters
  ): Promise<any> {
    const compareOneCommand: Command = this.tryGetCommand(
      "PROJECTDATA_COMMAND"
    );
    if (compareOneCommand) {
      // This command should be hidden unless exactly one row is selected.
      compareOneCommand.visible =
        event.selectedRows.length === 1 &&
        this.userAuthorized &&
        location.href.includes("Idebehandling");
    }
  }

  @override
  public onExecute(event: IListViewCommandSetExecuteEventParameters): any {
    switch (event.itemId) {
      case "PROJECTDATA_COMMAND":
        const dialog: DialogPrompt = new DialogPrompt();

        dialog.ideaTitle = event.selectedRows[0].getValueByName("Title");
        dialog.show().then(() => {
          if (dialog.comment && dialog.selectedChoice == "Godkjenn") {
            this.onSubmit(
              event.selectedRows[0],
              dialog.comment,
              dialog.selectedChoice
            );
          } else if (
            dialog.comment &&
            dialog.selectedChoice == "Under vurdering"
          ) {
            this.onSubmitConsideration(event.selectedRows[0], dialog.comment);
          } else if (dialog.comment && dialog.selectedChoice == "Avvis") {
            this.onSubmitDeclined(event.selectedRows[0], dialog.comment);
          } else {
            Logger.log({ message: "Declined", level: LogLevel.Info });
          }
        });
        break;
      default:
        throw new Error("Unknown command");
    }
  }

  /**
   * On submit and declined
   */
  private async onSubmitDeclined(selectedRow: RowAccessor, recComment: string) {
    const rowId = selectedRow.getValueByName("ID");
    sp.web.lists
      .getByTitle("Idébehandling")
      .items.getById(rowId)
      .update({
        GtIdeaDecision: RecommendationType.Declined,
        GtIdeaDecisionComment: recComment,
      })
      .then(() => console.log("Updated Idébehandling"));
  }

  /**
   * On submit and concideration
   */
  private async onSubmitConsideration(
    selectedRow: RowAccessor,
    recComment: string
  ) {
    const rowId = selectedRow.getValueByName("ID");
    sp.web.lists
      .getByTitle("Idébehandling")
      .items.getById(rowId)
      .update({
        GtIdeaDecision: RecommendationType.Consideration,
        GtIdeaDecisionComment: recComment,
      })
      .then(() => console.log("Updated Idébehandling"));
  }

  /**
   * On submit and approved
   */
  private async onSubmit(
    selectedRow: RowAccessor,
    recComment: string,
    recChoice: string
  ) {
    const rowId = selectedRow.getValueByName("ID");
    sp.web.lists
      .getByTitle("Idébehandling")
      .items.getById(rowId)
      .update({
        GtIdeaDecision: RecommendationType.Accepted,
        GtIdeaDecisionComment: recComment,
      })
      .then(() => console.log("Updated Idébehandling"));
  }

  /**
   * Checks if the current user has premisions to set recommendation
   */
  private async isUserAuthorized(): Promise<boolean> {
    const users = await sp.web.siteGroups.getByName("Idebehandlere").users();
    return users.some(
      (user) => user.Email == this.context.pageContext.user.email
    );
  }
}
