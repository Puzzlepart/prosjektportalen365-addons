import { find, first } from 'underscore';
import { contains } from 'underscore.string';
import { IFilter } from '../components/FilterPanel';
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
    public siteUrl: string;
    public title: string;
    public phase: string;
    public projectType: string;
    public serviceArea: string;

    constructor(private item: IProjectItem, public status: ProjectStatusModel[]) {
        this.siteId = item.GtSiteId;
        this.siteUrl = item.GtSiteUrl;
        this.title = item.Title;
        this.phase = item.GtProjectPhaseText;
        this.projectType = item.GtProjectTypeText;
        this.serviceArea = item.GtProjectServiceAreaText;
        this[this.phase] = first(status);
    }

    public setTitle(_title: string): ProjectModel {
        this.title = _title;
        return this;
    }

    /**
     * Get the SharePoint item for the project merged with the latest status report
    */
    public getMergedItem(): IProjectItem {
        return {
            ...this.status.length > 0 ? first(this.status).getItem() : {},
            ...this.item,
        };
    }

    /**
     * Check if the project matches the specified filters
     * 
     * @param {IFilter[]} filters Filters
     */
    public matchFilters(filters: IFilter[]): boolean {
        const _item = this.getMergedItem();
        for (let i = 0; i < filters.length; i++) {
            const filter = filters[i]
            if (filter.selected.length === 0) continue;
            const value = _item[filter.key];
            const match = find(filter.selected, s => contains(value, s.value));
            if (!match) return false;
        }
        return true;
    }
}