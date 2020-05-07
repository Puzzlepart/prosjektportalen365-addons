import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { IProjectOverviewContext } from './ProjectOverviewContext';

export const getColumns = ({ phases, properties }: IProjectOverviewContext): IColumn[] => [
    {
        key: 'title',
        name: 'Prosjekt',
        minWidth: 200,
        maxWidth: 220,
    } as IColumn,
    {
        key: 'projectType',
        name: 'Prosjekttype',
        minWidth: 120,
        maxWidth: 180,
        isMultiline: true,
    } as IColumn,
    {
        key: 'serviceArea',
        name: 'Tjenesteområde',
        minWidth: 120,
        maxWidth: 180,
        isMultiline: true,
    } as IColumn,
    ...phases.map(({ Name }) => ({
        key: Name,
        name: Name,
        minWidth: properties.statusColumnWidth,
        maxWidth: properties.statusColumnWidth,
    })),
].map(col => ({ ...col, isResizable: true }));