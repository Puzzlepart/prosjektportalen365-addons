import { Version } from '@microsoft/sp-core-library';
import { IPropertyPaneConfiguration, PropertyPaneButton, PropertyPaneDropdown, PropertyPaneLabel, PropertyPaneSlider, PropertyPaneToggle } from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import { dateAdd, DateAddInterval } from '@pnp/common';
import moment from 'moment';
import React from 'react';
import ReactDom from 'react-dom';
import { first } from 'underscore';
import { ProjectOverview } from './components/ProjectOverview';
import { DataAdapter } from './data';
import { ProjectModel } from './models/ProjectModel';
import { ProjectOverviewContext } from './ProjectOverviewContext';
import { IPhase, IProjectOverviewWebPartProps } from './types';

export default class ProjectOverviewWebPart extends BaseClientSideWebPart<IProjectOverviewWebPartProps> {
  private projects: Array<ProjectModel>;
  private phases: Array<IPhase>;
  private dataAdapter: DataAdapter;

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
    this.dataAdapter = new DataAdapter(this.context, {
      phaseTermSetId: this.createCacheKey('phase_term_set_id'),
      projects: this.createCacheKey('projects'),
      projectStatus: this.createCacheKey('project_status'),
      columnConfigurations: this.createCacheKey('column_configurations'),
      statusSections: this.createCacheKey('status_sections'),
    })
    const { projects, phases } = await this.dataAdapter.fetchData(this.getCacheExpiry());
    this.projects = projects;
    this.phases = phases;
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
                    this.dataAdapter.clearCache();
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
