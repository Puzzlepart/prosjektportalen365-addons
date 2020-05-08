import { IContextualMenuProps } from 'office-ui-fabric-react/lib/ContextualMenu';
import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { PortfolioConfiguration } from '../../models/PortfolioConfiguration';
import { ProjectModel } from '../../models/ProjectModel';
import { IFilter } from '../FilterPanel';

export interface IProjectOverviewState {
    projects: ProjectModel[];
    filters?: IFilter[];
    showFilterPanel?: boolean;
    columns?: IColumn[];
    columnMenu?: IContextualMenuProps;
    selectedConfiguration?: PortfolioConfiguration;
}
