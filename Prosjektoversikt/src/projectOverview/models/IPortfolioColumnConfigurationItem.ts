
export interface IPortfolioColumnItem {
    Title: string;
    GtInternalName: string;
}

export class IPortfolioColumnConfigurationItem {
    GtPortfolioColumn: IPortfolioColumnItem;
    GtPortfolioColumnValue: string;
    GtPortfolioColumnColor: string;
}
