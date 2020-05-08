import React from 'react';
import { DataAdapter } from '../../data';
import { PortfolioConfiguration } from '../../models/PortfolioConfiguration';
import { IProjectOverviewWebPartProps } from '../../types';
import { IProjectOverviewState } from './IProjectOverviewState';
import { ProjectOverviewAction } from './ProjectOverviewAction';

export interface IProjectOverviewContext {
    properties: IProjectOverviewWebPartProps;
    dataAdapter?: DataAdapter;
    dispatch?: React.Dispatch<ProjectOverviewAction>;
    configurations: PortfolioConfiguration[];
    defaultConfiguration?: PortfolioConfiguration;
    state?: IProjectOverviewState;
}

export const ProjectOverviewContext = React.createContext<IProjectOverviewContext>(null);
