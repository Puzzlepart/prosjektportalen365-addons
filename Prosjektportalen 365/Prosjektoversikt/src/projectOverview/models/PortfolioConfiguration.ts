export interface IPortfolioConfigurationItem {
    ID: number;
    Title: string;
    URL: string;
    IconName: string;
}

export class PortfolioConfiguration {
    public id: number;
    public title: string;
    public url: string;
    public iconName: string;

    constructor(item: IPortfolioConfigurationItem) {
        this.id = item.ID;
        this.title = item.Title;
        this.url = item.URL;
        this.iconName = item.IconName;
    }
}