import { MessageBarType } from "@fluentui/react";

export interface IProjectInfo {
    title: string;
    siteUrl: string;
    lifecycleStatus: string;
    phase?: string;
}

export interface IReactivateProjectDialogProps {
    azureFunctionUrl: string;
    project: IProjectInfo;
    version: string;
    close: () => void;
}

export interface IStatusMessage {
    type: MessageBarType;
    message: string;
}
