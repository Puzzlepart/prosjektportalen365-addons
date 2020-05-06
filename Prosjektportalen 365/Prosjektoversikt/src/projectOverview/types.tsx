export interface IProjectOverviewWebPartProps {
    statusColumnMinWidth: number;
    columnIconSize: number;
    showTooltip: boolean;
}

export type Phases = Array<{ Name: string; LocalCustomProperties: { [key: string]: string } }>;