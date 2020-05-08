import { PortfolioConfiguration } from './models/PortfolioConfiguration';
import { ProjectModel } from './models/ProjectModel';
import { IPhase } from './types';
export interface IDataAdapterFetchResult {
    projects: ProjectModel[];
    phases: IPhase[];
    configurations: PortfolioConfiguration[];
}
