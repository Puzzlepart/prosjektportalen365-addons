import { sp } from '@pnp/sp';
import config from './config';
import { IPortfolioColumnConfigurationItem } from './models/IPortfolioColumnConfigurationItem';


export const getPhaseFieldTermSetId = async (expiration: Date, key: string): Promise<string> => {
    const { TermSetId } = await sp
        .web
        .fields
        .getByInternalNameOrTitle(config.PHASE_FIELD_NAME)
        .select('TermSetId')
        .usingCaching({ key, expiration })
        .get<{ TermSetId: string }>();
    return TermSetId;
}

export const searchSitesInHub = async (siteId: string): Promise<{ [key: string]: string }> => {
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

export const getColumnConfigurations = async (expiration: Date, key: string) => {
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