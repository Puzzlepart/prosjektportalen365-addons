import React from 'react';
import { DataAdapter } from '../../data-adapter';
import { Portfolio } from '../../models/Portfolio';
import { IProjectOverviewWebPartProps } from '../../types';
import { IProjectOverviewState } from './IProjectOverviewState';
import { ProjectOverviewAction } from './ProjectOverviewAction';

export interface IProjectOverviewContext {
    properties: IProjectOverviewWebPartProps;
    dataAdapter?: DataAdapter;
    dispatch?: React.Dispatch<ProjectOverviewAction>;
    portfolios: Portfolio[];
    hoverColumns: any;
    defaultConfiguration?: Portfolio;
    state?: IProjectOverviewState;
}

export const ProjectOverviewContext = React.createContext<IProjectOverviewContext>(null);
