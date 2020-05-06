import { Version } from '@microsoft/sp-core-library';
import { IPropertyPaneConfiguration, PropertyPaneButton, PropertyPaneDropdown, PropertyPaneLabel, PropertyPaneSlider, PropertyPaneToggle } from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import { dateAdd, DateAddInterval } from '@pnp/common';
import { sp } from '@pnp/sp';
import { taxonomy } from '@pnp/sp-taxonomy';
import moment from 'moment';
import React from 'react';
import ReactDom from 'react-dom';
import { filter, first, pick } from 'underscore';
import { ProjectOverview } from './components/ProjectOverview';
import config from './config';
import { getColumnConfigurations, getPhaseFieldTermSetId, searchSitesInHub } from './data';
import { IStatusSectionItem } from './models/IStatusSectionItem';
import { IProjectItem, ProjectModel } from './models/ProjectModel';
import { IProjectStatusItem, ProjectStatusModel } from './models/ProjectStatusModel';
import { ProjectOverviewContext } from './ProjectOverviewContext';
import { IPhase, IProjectOverviewWebPartCacheKeys, IProjectOverviewWebPartProps } from './types';

export default class ProjectOverviewWebPart extends BaseClientSideWebPart<IProjectOverviewWebPartProps> {
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
    await super.onInit();
    moment.locale('nb');
    this.cacheKeys = {
      phaseTermSetId: this.createCacheKey('phase_term_set_id'),
      projects: this.createCacheKey('projects'),
      projectStatus: this.createCacheKey('project_status'),
      columnConfigurations: this.createCacheKey('column_configurations'),
      statusSections: this.createCacheKey('status_sections'),
    }
    await this.getData();
  }

  protected async getData() {
    sp.setup({ spfxContext: this.context, defaultCachingStore: 'session' });
    const expiration = this.getCacheExpiry();
    const phaseTermSetId = await getPhaseFieldTermSetId(expiration, this.cacheKeys.phaseTermSetId);
    const [
      _sites,
      _projects,
      _status,
      _columnConfigurations,
      _statusSections,
      _phases,
    ] = await Promise.all([
      searchSitesInHub(this.context.pageContext.site.id.toString()),
      sp.web.lists.getByTitle(config.PROJECTS_LIST_NAME)
        .items
        .top(500)
        .usingCaching({ key: this.cacheKeys.projects })
        .get<IProjectItem[]>(),
      sp.web.lists.getByTitle(config.PROJECT_STATUS_LIST_NAME)
        .items
        .top(500)
        .usingCaching({ key: this.cacheKeys.projectStatus, expiration })
        .get<IProjectStatusItem[]>(),
      getColumnConfigurations(expiration, this.cacheKeys.columnConfigurations),
      sp.web.lists.getByTitle(config.STATUS_SECTIONS_LIST_NAME)
        .items
        .select('GtSecFieldName', 'GtSecIcon')
        .top(10)
        .usingCaching({ key: this.cacheKeys.statusSections, expiration })
        .get<IStatusSectionItem[]>(),
      taxonomy.getDefaultKeywordTermStore().getTermSetById(phaseTermSetId).terms.get(),
    ]);
    const status = _status.map(item => new ProjectStatusModel(item, _columnConfigurations, _statusSections));
    this.projects = _projects
      .map(item => {
        const project = new ProjectModel(item, filter(status, s => s.siteId === item.GtSiteId));
        if (!_sites[project.siteId]) return null;
        return project.setTitle(_sites[project.siteId]);
      })
      .filter(p => p);
    this.phases = filter(_phases, p => {
      return p.LocalCustomProperties.ShowOnFrontpage !== 'false';
    }).map(p => pick(p, 'Name', 'LocalCustomProperties') as any);
  }

  protected createCacheKey(key: string) {
    return `${this.manifest.alias}_data_${key}`.toLowerCase();
  }

  protected getCacheExpiry() {
    let expiration = dateAdd(new Date(), 'hour', this.properties.cacheUnits);
    try {
      expiration = dateAdd(
        new Date(),
        this.properties.cacheInterval.split('|')[1] as DateAddInterval,
        this.properties.cacheUnits,
      );
    } catch (error) {
      expiration = dateAdd(new Date(), 'minute', 1);
    }
    return expiration;
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
                PropertyPaneSlider('statusColumnWidth', {
                  label: 'Bredde for statuskolonner',
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
                PropertyPaneSlider('columnIconGap', {
                  label: 'Avstand mellom statusikoner i kolonnene',
                  min: 5,
                  max: 15,
                  step: 1,
                }),
                PropertyPaneToggle('showTooltip', {
                  label: 'Vis tooltip',
                }),
                PropertyPaneLabel('showTooltip', {
                  text: 'Bestem om det skal vises en tooltip med oppsummering av statusrapporten.',
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
