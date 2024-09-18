export interface IPortfolioItem {
    ID: number;
    Title: string;
    URL: string;
    IconName: string;
    GtSearchQuery: string;
    GtTermSetId: string;
}

export class Portfolio {
    public id: number;
    public title: string;
    public url: string;
    public iconName: string;
    public termSetId: string;
    public searchQuery: string;
    public hoverColumns: any[];

    constructor(item: IPortfolioItem) {
        this.id = item.ID;
        this.title = item.Title;
        this.url = item.URL;
        this.termSetId = item.GtTermSetId;
        this.iconName = item.IconName;
        this.searchQuery = item.GtSearchQuery;
    }
}