import { first } from 'underscore';
import { ProjectStatusModel } from './ProjectStatusModel';

export interface IProjectItem {
    Id: number;
    ServerRedirectedEmbedUri?: any;
    ServerRedirectedEmbedUrl: string;
    ContentTypeId: string;
    Title: string;
    ComplianceAssetId?: any;
    GtProjectFinanceName?: any;
    GtProjectNumber?: any;
    GtArchiveReference?: any;
    GtProjectServiceArea: any[];
    GtProjectType: any[];
    GtProjectPhase?: any;
    GtProjectManagerId?: any;
    GtProjectManagerStringId?: any;
    GtProjectOwnerId?: any;
    GtProjectOwnerStringId?: any;
    GtGainsResponsibleId?: any;
    GtGainsResponsibleStringId?: any;
    GtStartDate?: any;
    GtEndDate?: any;
    GtProjectGoals?: any;
    GtGroupId: string;
    GtSiteId: string;
    GtSiteUrl: string;
    GtLastSyncTime?: any;
    GtProjectLifecycleStatus: string;
    GtProjectPhaseText?: any;
    GtProjectServiceAreaText?: any;
    GtProjectTypeText?: any;
    ID: number;
    Modified: Date;
    Created: Date;
    AuthorId: number;
    EditorId: number;
    OData__UIVersionString: string;
    Attachments: boolean;
    GUID: string;
}

export class ProjectModel {
    public siteId: string;
    public title: string;
    public phase: string;
    public projectType: string;
    public serviceArea: string;

    constructor(item: IProjectItem, public status: Array<ProjectStatusModel>) {
        this.siteId = item.GtSiteId;
        this.title = item.Title;
        this.phase = item.GtProjectPhaseText;
        this.projectType = item.GtProjectTypeText;
        this.serviceArea = item.GtProjectServiceAreaText;
        // TODO: Need to return the latest status, returning the first for now (it might be correct if we sort correctly)
        this[this.phase] = first(status);
    }

    public setTitle(_title: string): ProjectModel {
        this.title = _title;
        return this;
    }
}