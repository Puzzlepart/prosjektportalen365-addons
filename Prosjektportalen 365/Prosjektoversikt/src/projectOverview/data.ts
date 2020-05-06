import { WebPartContext } from '@microsoft/sp-webpart-base';
import { sp } from '@pnp/sp';
import { taxonomy } from '@pnp/sp-taxonomy';
import { filter, pick } from 'underscore';
import config from './config';
import { IPortfolioColumnConfigurationItem } from './models/IPortfolioColumnConfigurationItem';
import { IStatusSectionItem } from './models/IStatusSectionItem';
import { IProjectItem, ProjectModel } from './models/ProjectModel';
import { IProjectStatusItem, ProjectStatusModel } from './models/ProjectStatusModel';

export interface IDataAdapterCacheKeys {
    phaseTermSetId: string;
    projects: string;
    projectStatus: string;
    columnConfigurations: string;
    statusSections: string;
}

export class DataAdapter {
    constructor(
        private context: WebPartContext,
        private cacheKeys: IDataAdapterCacheKeys,
    ) {
        sp.setup({ spfxContext: this.context, defaultCachingStore: 'session' });
    }

    private async getPhaseFieldTermSetId(expiration: Date, key: string): Promise<string> {
        const { TermSetId } = await sp
            .web
            .fields
            .getByInternalNameOrTitle(config.PHASE_FIELD_NAME)
            .select('TermSetId')
            .usingCaching({ key, expiration })
            .get<{ TermSetId: string }>();
        return TermSetId;
    }

    private async searchSitesInHub(siteId: string): Promise<{ [key: string]: string }> {
        const { PrimarySearchResults } = await sp.search({
            Querytext: `DepartmentId:{${siteId}} contentclass:STS_Site`,
            TrimDuplicates: false,
            RowLimit: 500,
            SelectProperties: ['SiteId', 'Title'],
        });
        const sites = PrimarySearchResults.reduce((obj, siteResult) => ({
            ...obj,
            [siteResult['SiteId']]: siteResult['Title'],
        }), {} as { [key: string]: string });
        return sites;
    }

    private async getColumnConfigurations(expiration: Date, key: string) {
        const items = await sp.web.lists.getByTitle(config.PROJECT_COLUMN_CONFIGURATION_LIST_NAME)
            .items
            .select(
                'GtPortfolioColumnColor',
                'GtPortfolioColumnValue',
                'GtPortfolioColumn/Title',
                'GtPortfolioColumn/GtInternalName'
            )
            .expand('GtPortfolioColumn')
            // eslint-disable-next-line quotes
            .filter(`startswith(GtPortfolioColumn/GtInternalName,'GtStatus')`)
            .top(500)
            .usingCaching({ key, expiration })
            .get<IPortfolioColumnConfigurationItem[]>();
        const columnConfigurations = items.reduce((obj, item) => {
            const key = item.GtPortfolioColumn.GtInternalName;
            obj[key] = obj[key] || {};
            obj[key].name = obj[key].name || item.GtPortfolioColumn.Title;
            obj[key].colors = obj[key].colors || {};
            obj[key].colors[item.GtPortfolioColumnValue] = item.GtPortfolioColumnColor;
            return obj;
        }, {});
        return columnConfigurations;
    }

    public clearCache() {
        Object.keys(this.cacheKeys)
            .forEach(key => sessionStorage.removeItem(this.cacheKeys[key]));
    }

    public async fetchData(
        expiration: Date,
    ) {
        const projectsList = sp.web.lists.getByTitle(config.PROJECTS_LIST_NAME);
        const projectStatusList = sp.web.lists.getByTitle(config.PROJECT_STATUS_LIST_NAME);
        const statusSectionsList = sp.web.lists.getByTitle(config.STATUS_SECTIONS_LIST_NAME);
        const phaseTermSetId = await this.getPhaseFieldTermSetId(expiration, this.cacheKeys.phaseTermSetId);
        const [
            _sites,
            _projects,
            _status,
            _columnConfigurations,
            _statusSections,
            _phases,
        ] = await Promise.all([
            this.searchSitesInHub(this.context.pageContext.site.id.toString()),
            projectsList
                .items
                .top(500)
                .usingCaching({ key: this.cacheKeys.projects, expiration })
                .get<IProjectItem[]>(),
            projectStatusList
                .items
                .top(500)
                .orderBy('Id', false)
                .usingCaching({ key: this.cacheKeys.projectStatus, expiration })
                .get<IProjectStatusItem[]>(),
            this.getColumnConfigurations(expiration, this.cacheKeys.columnConfigurations),
            statusSectionsList
                .items
                .select('GtSecFieldName', 'GtSecIcon')
                .top(10)
                .usingCaching({ key: this.cacheKeys.statusSections, expiration })
                .get<IStatusSectionItem[]>(),
            taxonomy.getDefaultKeywordTermStore().getTermSetById(phaseTermSetId).terms.get(),
        ]);

        const status = _status.map(item => new ProjectStatusModel(
            item,
            _columnConfigurations,
            _statusSections,
        ));
        const projects = _projects
            .map(item => {
                const project = new ProjectModel(item, filter(status, s => s.siteId === item.GtSiteId));
                if (!_sites[project.siteId]) return null;
                return project.setTitle(_sites[project.siteId]);
            })
            .filter(p => p);
        const phases = filter(_phases, p => {
            return p.LocalCustomProperties.ShowOnFrontpage !== 'false';
        }).map(p => pick(p, 'Name', 'LocalCustomProperties') as any);
        return { projects, phases };
    }
}