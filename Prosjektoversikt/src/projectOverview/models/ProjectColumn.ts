export interface IProjectColumnItem {
    Title: string;
    GtInternalName: string;
}

export class ProjectColumn {
    public name: string;
    public fieldName: string;

    constructor(item: IProjectColumnItem) {
        this.name = item.Title;
        this.fieldName = item.GtInternalName;
    }
}