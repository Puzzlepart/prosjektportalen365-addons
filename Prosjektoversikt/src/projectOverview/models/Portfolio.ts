export interface IPortfolioItem {
    ID: number;
    Title: string;
    URL: string;
    IconName: string;
    GtSearchQuery: string;
}

export class Portfolio {
    public id: number;
    public title: string;
    public url: string;
    public iconName: string;
    public searchQuery: string;
    public hoverColumns: any[];

    constructor(item: IPortfolioItem) {
        this.id = item.ID;
        this.title = item.Title;
        this.url = item.URL;
        this.iconName = item.IconName;
        this.searchQuery = item.GtSearchQuery;
    }
}