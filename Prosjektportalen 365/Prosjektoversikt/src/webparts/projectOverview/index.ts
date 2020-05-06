/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-empty-interface */
import { Version } from '@microsoft/sp-core-library';
import { BaseClientSideWebPart, IPropertyPaneConfiguration } from '@microsoft/sp-webpart-base';
import { sp } from '@pnp/pnpjs';
import moment from 'moment';
import * as React from 'react';
import * as ReactDom from 'react-dom';
import { filter } from 'underscore';
import { IProjectOverviewProps } from './components/IProjectOverviewProps';
import ProjectOverview from './components/ProjectOverview';
import { IPortfolioColumnConfigurationItem } from './models/IPortfolioColumnConfigurationItem';
import { IStatusSectionItem } from './models/IStatusSectionItem';
import { IProjectItem, ProjectModel } from './models/ProjectModel';
import { IProjectStatusItem, ProjectStatusModel } from './models/ProjectStatusModel';

export interface IProjectOverviewWebPartProps { }

export default class ProjectOverviewWebPart extends BaseClientSideWebPart<IProjectOverviewWebPartProps> {
  private projects: Array<ProjectModel>;

  public render(): void {
    const element: React.ReactElement<IProjectOverviewProps> = React.createElement(
      ProjectOverview,
      { projects: this.projects }
    );

    ReactDom.render(element, this.domElement);
  }

  public async onInit() {
    moment.locale('nb');
    await super.onInit();
    await this.getData();
  }

  protected async getData() {
    sp.setup({
      spfxContext: this.context,
      pageContext: this.context.pageContext,
      defaultCachingTimeoutSeconds: 1000000,
    });
    const [_projects, _status, _columnConfigurations, _statusSections] = await Promise.all([
      sp.web.lists.getByTitle('Prosjekter')
        .items
        .usingCaching()
        .top(500)
        .get<IProjectItem[]>(),
      sp.web.lists.getByTitle('Prosjektstatus')
        .items
        .top(500)
        .usingCaching()
        .get<IProjectStatusItem[]>(),
      sp.web.lists.getByTitle('Prosjektkolonnekonfigurasjon')
        .items
        .select(
          'GtPortfolioColumnColor',
          'GtPortfolioColumnValue',
          'GtPortfolioColumn/Title',
          'GtPortfolioColumn/GtInternalName'
        )
        .expand('GtPortfolioColumn')
        // eslint-disable-next-line quotes
        .filter(`startswith(GtPortfolioColumn/GtInternalName,'GtStatus')`)
        .top(500)
        .usingCaching()
        .get<IPortfolioColumnConfigurationItem[]>(),
      sp.web.lists.getByTitle('Statusseksjoner')
        .items
        .select(
          'GtSecFieldName',
          'GtSecIcon',
        )
        .top(10)
        .usingCaching()
        .get<IStatusSectionItem[]>(),
    ]);
    console.log(_statusSections);
    const columnConfigurations = _columnConfigurations.reduce((obj, item) => {
      const key = item.GtPortfolioColumn.GtInternalName;
      obj[key] = obj[key] || {};
      obj[key].name = obj[key].name || item.GtPortfolioColumn.Title;
      obj[key].colors = obj[key].colors || {};
      obj[key].colors[item.GtPortfolioColumnValue] = item.GtPortfolioColumnColor;
      return obj;
    }, {});
    const status = _status.map(item => new ProjectStatusModel(item, columnConfigurations, _statusSections));
    this.projects = _projects.map(item => new ProjectModel(item, filter(status, s => s.siteId === item.GtSiteId)));
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse(this.manifest.version);
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: []
    };
  }
}
