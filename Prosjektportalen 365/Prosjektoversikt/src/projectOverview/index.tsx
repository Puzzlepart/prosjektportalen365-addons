import { Version } from '@microsoft/sp-core-library';
import { BaseClientSideWebPart, IPropertyPaneConfiguration, PropertyPaneButton, PropertyPaneDropdown, PropertyPaneLabel, PropertyPaneSlider, PropertyPaneToggle } from '@microsoft/sp-webpart-base';
import { dateAdd, DateAddInterval } from '@pnp/common';
import { sp } from '@pnp/sp';
import { taxonomy } from '@pnp/sp-taxonomy';
import moment from 'moment';
import React from 'react';
import ReactDom from 'react-dom';
import { filter, first, pick } from 'underscore';
import { ProjectOverview } from './components/ProjectOverview';
import config from './config';
import { IPortfolioColumnConfigurationItem } from './models/IPortfolioColumnConfigurationItem';
import { IStatusSectionItem } from './models/IStatusSectionItem';
import { IProjectItem, ProjectModel } from './models/ProjectModel';
import { IProjectStatusItem, ProjectStatusModel } from './models/ProjectStatusModel';
import { ProjectOverviewContext } from './ProjectOverviewContext';
import { IPhase, IProjectOverviewWebPartCacheKeys, IProjectOverviewWebPartProps } from './types';

export default class ProjectOverviewWebPart extends BaseClientSideWebPart<IProjectOverviewWebPartProps> {
  private lists = {
    projects: sp.web.lists.getByTitle(config.PROJECTS_LIST_NAME),
    projectColumConfiguration: sp.web.lists.getByTitle(config.PROJECT_COLUMN_CONFIGURATION_LIST_NAME),
    projectStatus: sp.web.lists.getByTitle(config.PROJECT_STATUS_LIST_NAME),
    statusSections: sp.web.lists.getByTitle(config.STATUS_SECTIONS_LIST_NAME),
  };
  private cacheKeys: IProjectOverviewWebPartCacheKeys;
  private projects: Array<ProjectModel>;
  private phases: Array<IPhase>;

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
    this.cacheKeys = {
      phaseTermSetId: this.makeStorageKey('phase_term_set_id'),
      projects: this.makeStorageKey('projects'),
      projectStatus: this.makeStorageKey('project_status'),
      columnConfigurations: this.makeStorageKey('column_configurations'),
      statusSections: this.makeStorageKey('status_sections'),
    }
    await super.onInit();
    await this.getData();
  }

  protected async getData() {
    sp.setup({ spfxContext: this.context, defaultCachingStore: 'session' });
    const expiration = dateAdd(new Date(), 'hour', 1);
    const { TermSetId } = await sp
      .web
      .fields
      .getByInternalNameOrTitle(config.PHASE_FIELD_NAME)
      .select('TermSetId')
      .usingCaching({ key: this.cacheKeys.phaseTermSetId, expiration })
      .get<{ TermSetId: string }>();
    const [_projects, _status, _columnConfigurations, _statusSections, _phases] = await Promise.all([
      this.lists.projects
        .items
        .top(500)
        .usingCaching({ key: this.cacheKeys.projects })
        .get<IProjectItem[]>(),
      this.lists.projectStatus
        .items
        .top(500)
        .usingCaching({ key: this.cacheKeys.projectStatus, expiration })
        .get<IProjectStatusItem[]>(),
      this.lists.projectColumConfiguration
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
        .usingCaching({ key: this.cacheKeys.columnConfigurations, expiration })
        .get<IPortfolioColumnConfigurationItem[]>(),
      this.lists.statusSections
        .items
        .select(
          'GtSecFieldName',
          'GtSecIcon',
        )
        .top(10)
        .usingCaching({ key: this.cacheKeys.statusSections, expiration })
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
    return Version.parse('1.0');
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    let cacheLabel: string;
    if (this.properties.cacheInterval && this.properties.cacheUnits) {
      cacheLabel = `Hurtigbuffer er satt til å vare i ${this.properties.cacheUnits} ${first(this.properties.cacheInterval.split('|'))}`;
    }
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
        },
        {
          groups: [
            {
              groupName: 'Hurtigbuffer',
              groupFields: [
                PropertyPaneDropdown('cacheInterval', {
                  label: 'Enhet',
                  options: [
                    {
                      key: 'minutter|minute',
                      text: 'Minutter',
                    },
                    {
                      key: 'timer|hour' as DateAddInterval,
                      text: 'Timer',
                    },
                    {
                      key: 'dager|day' as DateAddInterval,
                      text: 'Dager',
                    }
                  ]
                }),
                PropertyPaneSlider('cacheUnits', {
                  label: 'Antal',
                  min: 1,
                  max: 60,
                  step: 1,
                }),
                PropertyPaneLabel('cacheUnits', { text: cacheLabel }),
                PropertyPaneButton('cacheUnits', {
                  text: 'Tøm hurtigbuffer',
                  onClick: () => {
                    Object.keys(this.cacheKeys).forEach(key => sessionStorage.removeItem(this.cacheKeys[key]));
                    document.location.reload();
                  }
                }),
              ]
            },
          ]
        }
      ]
    };
  }
}
