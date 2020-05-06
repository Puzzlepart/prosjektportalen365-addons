export interface IProjectOverviewWebPartProps {
    /**
     * Min width for status columns
     */
    statusColumnMinWidth: number;

    /**
    * Icon size in columns
    */
    columnIconSize: number;

    /**
     * Show tooltip on hover on status columns
     */
    showTooltip: boolean;

    /**
     * Cache interval
     */
    cacheInterval: string;

    /**
     * Cache units
     */
    cacheUnits: number;
}

export interface IPhase {
    Name: string;
    LocalCustomProperties: { [key: string]: string };
}

export interface IProjectOverviewWebPartCacheKeys {
    phaseTermSetId: string;
    projects: string;
    projectStatus: string;
    columnConfigurations: string;
    statusSections: string;
}