import * as React from 'react';
import { ProjectModel } from './models/ProjectModel';
import { IPhase, IProjectOverviewWebPartProps } from './types';

export interface IProjectOverviewContext {
    properties: IProjectOverviewWebPartProps;
    projects: ProjectModel[];
    phases: Array<IPhase>;
}

export const ProjectOverviewContext = React.createContext<IProjectOverviewContext>(null);
