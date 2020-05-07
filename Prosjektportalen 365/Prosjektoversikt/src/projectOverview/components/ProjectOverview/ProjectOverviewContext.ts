import * as React from 'react';
import { IDataAdapterFetchResult } from '../../data';
import { IProjectOverviewWebPartProps } from '../../types';
import { IFilter } from '../FilterPanel';
import { ProjectOverviewAction } from './ProjectOverviewReducer';

export interface IProjectOverviewContext extends IDataAdapterFetchResult {
    properties: IProjectOverviewWebPartProps;
    filters: IFilter[];
    dispatch?: React.Dispatch<ProjectOverviewAction>;
}

export const ProjectOverviewContext = React.createContext<IProjectOverviewContext>(null);
