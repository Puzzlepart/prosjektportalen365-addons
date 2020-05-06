import * as React from 'react';
import { ProjectModel } from './models/ProjectModel';
import { IProjectOverviewWebPartProps, Phases } from './types';

export const ProjectOverviewContext = React.createContext<{
    properties: IProjectOverviewWebPartProps;
    projects: ProjectModel[];
    phases: Phases;
}>(null);
