/* eslint-disable @typescript-eslint/no-unused-vars */
import { CommandBar } from 'office-ui-fabric-react/lib/CommandBar';
import { ContextualMenuItemType, IContextualMenuItem } from 'office-ui-fabric-react/lib/ContextualMenu';
import React from 'react';
import { IProjectOverviewContext, ProjectOverviewContext } from '../ProjectOverview/ProjectOverviewContext';
import styles from './ActionBar.module.scss';

const PortfolioSelector = ({
    dispatch,
    portfolios: configurations,
    state,
}: IProjectOverviewContext): IContextualMenuItem => ({
    key: 'PORTFOLIO_SELECTOR',
    itemType: ContextualMenuItemType.Header,
    iconProps: { iconName: 'ProjectCollection' },
    name: 'Portefølje',
    subMenuProps: {
        items: [
            ...configurations.map(conf => ({
                key: `conf_${conf.id.toString()}`,
                name: conf.title,
                iconProps: { iconName: conf.iconName },
                termStoreId: conf.termSetId,
                canCheck: true,
                checked: conf.id === state.selectedPortfolio.id,
                onClick: () => {
                    dispatch({ type: 'CHANGE_CONFIGURATION', payload: conf });
                },
            })),
            {
                key: 'divider_01',
                itemType: ContextualMenuItemType.Divider,
            },
            {
                key: 'admin_01',
                iconProps: { iconName: 'Admin' },
                name: 'Administrer porteføljer',
                href: '../Lists/Prosjektoversiktkonfigurasjon/AllItems.aspx',
                target: '_blank',
            }
        ]
    }
});

const FilterPanelToggle = ({ dispatch }: IProjectOverviewContext): IContextualMenuItem => ({
    key: 'OPEN_FILTER_PANEL',
    iconOnly: true,
    iconProps: { iconName: 'Filter' },
    onClick: () => dispatch({ type: 'TOGGLE_FILTER_PANEL' }),
}
)
export const ActionBar = () => {
    const context = React.useContext(ProjectOverviewContext);
    return (
        <div className={styles.root} >
            <CommandBar
                items={[]}
                farItems={[
                    PortfolioSelector(context),
                    FilterPanelToggle(context),
                ]} />
        </div>
    );
}
