import { IContextualMenuProps } from 'office-ui-fabric-react/lib/ContextualMenu';
import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { IProgressIndicatorProps } from 'office-ui-fabric-react/lib/ProgressIndicator';
import { IDataAdapterFetchResult } from '../../data-adapter/IDataAdapterFetchResult';
import { Portfolio } from '../../models/Portfolio';
import { ProjectModel } from '../../models/ProjectModel';
import { IFilter } from '../FilterPanel';

export interface IProjectOverviewState extends IDataAdapterFetchResult {
    loading?: IProgressIndicatorProps;
    projects?: ProjectModel[];
    projectInfo?: any[];
    filters?: IFilter[];
    showFilterPanel?: boolean;
    columns?: IColumn[];
    columnMenu?: IContextualMenuProps;
    selectedPortfolio?: Portfolio;
    hoverColumns?: any[];
}
