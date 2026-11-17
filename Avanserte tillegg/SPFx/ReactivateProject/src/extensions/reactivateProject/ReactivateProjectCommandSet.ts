import { Log } from '@microsoft/sp-core-library';
import {
  BaseListViewCommandSet,
  type Command,
  type IListViewCommandSetExecuteEventParameters,
  type ListViewStateChangedEventArgs,
  type RowAccessor
} from '@microsoft/sp-listview-extensibility';
import ReactivateProjectDialogBase from './ReactivateProjectDialogBase';
import { IProjectInfo } from './model/types';

export interface IReactivateProjectCommandSetProperties {
  azureFunctionUrl: string;
}

const LOG_SOURCE: string = 'ReactivateProjectCommandSet';
const PROJECTS_LIST_TITLE: string = 'Prosjekter';
const ARCHIVED_STATUS: string = 'Avsluttet';

export default class ReactivateProjectCommandSet extends BaseListViewCommandSet<IReactivateProjectCommandSetProperties> {
  private _listTitle: string | undefined;
  private _isAdmin: boolean;
  private _project: IProjectInfo | undefined;

  public onInit(): Promise<void> {
    Log.info(LOG_SOURCE, 'Initialized ReactivateProjectCommandSet');

    const command: Command = this.tryGetCommand('REACTIVATE_PROJECT');
    if (command) command.visible = false;

    this.context.listView.listViewStateChangedEvent.add(this, this._onListViewStateChanged);
    this._listTitle = this.context.pageContext.list?.title;
    this._isAdmin = this.context.pageContext.legacyPageContext.isSiteAdmin;

    return Promise.resolve();
  }

  public onExecute(event: IListViewCommandSetExecuteEventParameters): void {
    if (event.itemId === 'REACTIVATE_PROJECT' && this._project) {
      const dialog: ReactivateProjectDialogBase = new ReactivateProjectDialogBase(
        this._project,
        this.properties.azureFunctionUrl,
        this.manifest.version);
      dialog.show().catch((error: Error) => Log.error(LOG_SOURCE, error));
    }
  }

  private _onListViewStateChanged = (args: ListViewStateChangedEventArgs): void => {
    Log.info(LOG_SOURCE, 'List view state changed');

    this._project = this._tryGetArchivedProject();

    const command: Command = this.tryGetCommand('REACTIVATE_PROJECT');
    if (command) {
      command.visible = this._listTitle === PROJECTS_LIST_TITLE && this._isAdmin && this._project !== undefined;
    }

    this.raiseOnChange();
  }

  /**
   * Returns the selected project, but only when exactly one row is selected and that project is
   * archived. Returns undefined otherwise, which is what hides the command.
   *
   * The row is read behind a length check on purpose: selectedRows is an empty array (not
   * undefined) once the selection is cleared, so reading selectedRows[0] directly throws and
   * aborts this handler before the command visibility is ever recalculated.
   */
  private _tryGetArchivedProject(): IProjectInfo | undefined {
    const selectedRows: ReadonlyArray<RowAccessor> = this.context.listView.selectedRows ?? [];
    if (selectedRows.length !== 1) return undefined;

    const row: RowAccessor = selectedRows[0];
    const lifecycleStatus: string = row.getValueByName('GtProjectLifecycleStatus');
    const isArchived: boolean = lifecycleStatus === ARCHIVED_STATUS
      && row.getValueByName('GtIsArchived') === 'Ja';

    if (!isArchived) return undefined;

    return {
      title: row.getValueByName('Title'),
      siteUrl: row.getValueByName('GtSiteUrl'),
      lifecycleStatus: lifecycleStatus,
      phase: row.getValueByName('GtProjectPhaseText')
    };
  }
}
