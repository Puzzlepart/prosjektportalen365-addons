import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { IProjectOverviewContext } from './ProjectOverviewContext';

export const getColumns = ({ state, properties }: IProjectOverviewContext): IColumn[] => [
    {
        key: 'title',
        name: 'Prosjekt',
        minWidth: 200,
        maxWidth: 220,
        data: { isSortable: true }
    } as IColumn,
    {
        key: 'projectType',
        name: 'Prosjekttype',
        minWidth: 120,
        maxWidth: 180,
        isMultiline: true,
        data: { isSortable: true }
    } as IColumn,
    {
        key: 'serviceArea',
        name: 'Tjenesteområde',
        minWidth: 120,
        maxWidth: 180,
        isMultiline: true,
        data: { isSortable: true }
    } as IColumn,
    ...(state.phases || []).map(({ Name }) => ({
        key: Name,
        name: Name,
        minWidth: properties.statusColumnWidth,
        maxWidth: properties.statusColumnWidth,
        data: {},
        headerClassName: Name,
    } as IColumn)),
].map(col => ({ ...col, isResizable: true }));