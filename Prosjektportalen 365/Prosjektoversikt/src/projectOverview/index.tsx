import { Version } from '@microsoft/sp-core-library';
import { BaseClientSideWebPart, IPropertyPaneConfiguration, PropertyPaneSlider, PropertyPaneToggle } from '@microsoft/sp-webpart-base';
import { dateAdd } from '@pnp/common';
import { sp } from '@pnp/sp';
import { taxonomy } from '@pnp/sp-taxonomy';
import moment from 'moment';
import * as React from 'react';
import * as ReactDom from 'react-dom';
import { filter, pick } from 'underscore';
import { ProjectOverview } from './components/ProjectOverview';
import { IPortfolioColumnConfigurationItem } from './models/IPortfolioColumnConfigurationItem';
import { IStatusSectionItem } from './models/IStatusSectionItem';
import { IProjectItem, ProjectModel } from './models/ProjectModel';
import { IProjectStatusItem, ProjectStatusModel } from './models/ProjectStatusModel';
import { ProjectOverviewContext } from './ProjectOverviewContext';
import { IProjectOverviewWebPartProps, Phases } from './types';

export default class ProjectOverviewWebPart extends BaseClientSideWebPart<IProjectOverviewWebPartProps> {
  private projects: Array<ProjectModel>;
  private phases: Phases;

  public render(): void {
    const element = (
      <ProjectOverviewContext.Provider
        value={{
          properties: this.properties,
          projects: this.projects,
          phases: this.phases,
        }}>
        <ProjectOverview />
      </ProjectOverviewContext.Provider>
    )
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
      defaultCachingStore: 'session',
    });
    const expiration = dateAdd(new Date(), 'hour', 1);
    const { TermSetId } = await sp.web.fields.getByInternalNameOrTitle('GtProjectPhase').select('TermSetId').get<{ TermSetId: string }>();
    const [_projects, _status, _columnConfigurations, _statusSections, _phases] = await Promise.all([
      sp.web.lists.getByTitle('Prosjekter')
        .items
        .top(500)
        .usingCaching({ key: this.makeStorageKey('projects'), expiration })
        .get<IProjectItem[]>(),
      sp.web.lists.getByTitle('Prosjektstatus')
        .items
        .top(500)
        .usingCaching({ key: this.makeStorageKey('project_status'), expiration })
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
        .usingCaching({ key: this.makeStorageKey('configurations'), expiration })
        .get<IPortfolioColumnConfigurationItem[]>(),
      sp.web.lists.getByTitle('Statusseksjoner')
        .items
        .select(
          'GtSecFieldName',
          'GtSecIcon',
        )
        .top(10)
        .usingCaching({ key: this.makeStorageKey('status_sections'), expiration })
        .get<IStatusSectionItem[]>(),
      taxonomy.getDefaultKeywordTermStore().getTermSetById(TermSetId).terms.get(),
    ]);
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
    this.phases = filter(_phases, p => {
      return p.LocalCustomProperties.ShowOnFrontpage !== 'false';
    }).map(p => pick(p, 'Name', 'LocalCustomProperties') as any);
  }

  protected makeStorageKey(key: string) {
    return `${this.manifest.alias}_data_${key}`.toLowerCase();
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse(this.manifest.version);
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          groups: [
            {
              groupName: 'Utseende',
              groupFields: [
                PropertyPaneSlider('statusColumnMinWidth', {
                  label: 'Minimum bredde for statuskolonner',
                  min: 100,
                  max: 250,
                  step: 5,
                }),
                PropertyPaneSlider('columnIconSize', {
                  label: 'Størrelse for statusikoner i kolonnene',
                  min: 10,
                  max: 25,
                  step: 1,
                }),
                PropertyPaneToggle('showTooltip', {
                  label: 'Vis tooltip',
                }),
              ]
            },
          ]
        }
      ]
    };
  }
}
