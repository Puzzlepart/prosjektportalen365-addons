export interface IProjectOverviewWebPartProps {
    /**
     * Min width for status columns
     */
    statusColumnWidth: number;

    /**
    * Icon size in columns
    */
    columnIconSize: number;

    /**
    * Icon gap in columns
    */
    columnIconGap: number;

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

    /**
     * Project list name
     */
    selectedHoverFields: string;
}

export interface IPhase {
    Name: string;
    LocalCustomProperties: { [key: string]: string };
}