import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { BaseDialog } from '@microsoft/sp-dialog';
import ReactivateProjectDialog from './components/ReactivateProjectDialog';
import { IProjectInfo } from './model/types';

export default class ReactivateProjectDialogBase extends BaseDialog {
    private _version: string;
    private _azureFunctionUrl: string;
    private _project: IProjectInfo;

    constructor(project: IProjectInfo, azureFunctionUrl: string, version: string) {
        super({ isBlocking: true });
        this._azureFunctionUrl = azureFunctionUrl;
        this._project = project;
        this._version = version;
    }

    public render(): void {
        ReactDOM.render(React.createElement(ReactivateProjectDialog, {
            version: this._version,
            project: this._project,
            azureFunctionUrl: this._azureFunctionUrl,
            close: this.close
        }), this.domElement);
    }

    public onAfterClose(): void {
        super.onAfterClose();
        ReactDOM.unmountComponentAtNode(this.domElement);
    }
}
