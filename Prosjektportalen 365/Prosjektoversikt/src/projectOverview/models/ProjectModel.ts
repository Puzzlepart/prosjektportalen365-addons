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
    public title: string;
    public phase: string;
    public projectType: string;
    public serviceArea: string;

    constructor(project: IProjectItem, public status: Array<ProjectStatusModel>) {
        this.title = project.Title;
        this.phase = project.GtProjectPhaseText;
        this.projectType = project.GtProjectTypeText;
        this.serviceArea = project.GtProjectServiceAreaText;
        // TODO: Need to return the latest status, returning the first for now (it might be correct if we sort correctly)
        this[this.phase] = first(status);
    }
}