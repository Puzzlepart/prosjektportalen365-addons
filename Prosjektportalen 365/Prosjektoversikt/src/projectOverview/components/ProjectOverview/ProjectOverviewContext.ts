import React from 'react';
import { IDataAdapterFetchResult } from '../../IDataAdapterFetchResult';
import { PortfolioConfiguration } from '../../models/PortfolioConfiguration';
import { IProjectOverviewWebPartProps } from '../../types';
import { IProjectOverviewState } from './IProjectOverviewState';
import { ProjectOverviewAction } from './ProjectOverviewAction';

export interface IProjectOverviewContext extends IDataAdapterFetchResult, IProjectOverviewState {
    properties: IProjectOverviewWebPartProps;
    dispatch?: React.Dispatch<ProjectOverviewAction>;
    defaultConfiguration?: PortfolioConfiguration;
}

export const ProjectOverviewContext = React.createContext<IProjectOverviewContext>(null);
