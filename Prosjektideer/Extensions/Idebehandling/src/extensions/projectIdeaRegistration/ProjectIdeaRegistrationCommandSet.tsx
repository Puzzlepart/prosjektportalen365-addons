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
import { ClientsideText, sp } from "@pnp/sp/presets/all";
import DialogPrompt from "./Components/Dialog";
import { ConsoleListener, Logger, LogLevel } from "@pnp/logging";

Logger.subscribe(new ConsoleListener());
Logger.activeLogLevel = DEBUG ? LogLevel.Info : LogLevel.Warning;
const LOG_SOURCE: string = "ProjectIdeaRegistrationCommandSet";

enum RecommendationType {
  Accepted = "Godkjent for detaljering av idé",
  Consideration = "Under vurdering",
  Declined = "Avvist",
}

export default class ProjectIdeaRegistrationCommandSet extends BaseListViewCommandSet<any> {
  private userAuthorized: boolean;

  @override
  public async onInit(): Promise<void> {
    Log.info(LOG_SOURCE, "Initialized ProjectIdeaRegistrationCommandSet");
    this.userAuthorized = await this.isUserAuthorized();

    return Promise.resolve();
  }

  @override
  public async onListViewUpdated(
    event: IListViewCommandSetListViewUpdatedParameters
  ): Promise<any> {
    const compareOneCommand: Command = this.tryGetCommand(
      "RECOMMENDATION_COMMAND"
    );
    if (compareOneCommand) {
      // This command should be hidden unless exactly one row is selected.
      compareOneCommand.visible =
        event.selectedRows.length === 1 && this.userAuthorized;
    }
  }

  @override
  public onExecute(event: IListViewCommandSetExecuteEventParameters): any {
    switch (event.itemId) {
      case "RECOMMENDATION_COMMAND":
        Dialog.alert("");
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
          } else {
            Logger.log({ message: "Declined", level: LogLevel.Info });
          }
        });
        break;
      default:
        throw new Error("Unknown command");
    }
  }

  private async onSubmitConsideration(
    selectedRow: RowAccessor,
    recComment: string
  ) {
    const rowId = selectedRow.getValueByName("ID");
    sp.web.lists
      .getByTitle("Idéregistrering")
      .items.getById(rowId)
      .update({
        GtIdeaRecommendation: RecommendationType.Consideration,
        GtIdeaRecommendationComment: recComment,
      })
      .then(() => console.log("Updated Idéregistrering"));
  }

  /**
   * When submit button of the dialog is pressed fields will be updated, written to a new list, then a sitepage will be created
   */
  private async onSubmit(
    selectedRow: RowAccessor,
    recComment: string,
    recChoice: string
  ) {
    const rowId = selectedRow.getValueByName("ID");
    const rowTitle = selectedRow.getValueByName("Title");
    sp.web.lists
      .getByTitle("Idéregistrering")
      .items.getById(rowId)
      .update({
        GtIdeaRecommendation: RecommendationType.Accepted,
        GtIdeaRecommendationComment: recComment,
      })
      .then(() => console.log("Updated Idéregistrering"));

    this.updateWorkList(rowId, rowTitle);
    this.createSitePage(selectedRow);
  }

  /**
   * Update the work list with selected values of the registration list
   */
  private updateWorkList(rowId: number, rowTitle: string) {
    sp.web.lists
      .getByTitle("Idébehandling")
      .items.add({
        Title: rowTitle,
        Registrert_x0020_ideId: rowId,
      })
      .then(() => console.log("Items transferred to Idébehandling"));
  }

  /**
   * Example of sitepage creation
   */
  private async createSitePage(row: RowAccessor) {
    const title = row.getValueByName("Title");
    console.log(row);
    const page = await sp.web.addClientsidePage(title, title, "Home");

    page.addSection().addControl(
      new ClientsideText(`
    Tittel: ${row.getValueByName("Title")} <br>
    Bakgrunn: ${row.getValueByName("GtIdeaBackground")} <br>
    Problemstilling: ${row.getValueByName("GtIdeaIssue")} <br>
    Bakgrunn: ${row.getValueByName("GtIdeaPossibleGains")} <br>
    `)
    );

    const res = await page.save();
    console.log(res);
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
