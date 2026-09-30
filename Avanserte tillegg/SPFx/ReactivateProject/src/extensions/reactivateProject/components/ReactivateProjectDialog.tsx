import { DefaultButton, DialogContent, DialogFooter, MessageBar, MessageBarType, PrimaryButton, Spinner, SpinnerSize } from '@fluentui/react';
import * as React from 'react';
import styles from './ReactivateProjectDialog.module.scss';
import { activateProject } from '../data';
import { IReactivateProjectDialogProps, IStatusMessage } from '../model/types';
const { useState } = React;

const ReactivateProjectDialog = ({ project, azureFunctionUrl, version, close }: IReactivateProjectDialogProps): JSX.Element => {
    const [activating, setActivating] = useState(false);
    const [statusMessage, setStatusMessage] = useState<IStatusMessage | null>(null);

    const initiateProjectActivation = async (): Promise<void> => {
        const status = await activateProject(azureFunctionUrl, project.siteUrl, setActivating)
        if (status === 200 || status === 202) {
            setStatusMessage({ type: MessageBarType.success, message: 'Prosjektet vil nå bli aktivt. Dette tar noen minutter.' });
        } else setStatusMessage({ type: MessageBarType.error, message: 'Noe gikk galt. Prosjektet ble ikke aktivert.' });
    };

    const renderProjectSummary = (): JSX.Element => (
        <dl className={styles.projectSummary}>
            <dt>Tittel</dt>
            <dd>{project.title}</dd>
            <dt>Prosjektstatus</dt>
            <dd>{project.lifecycleStatus}</dd>
            <dt>Fase</dt>
            <dd>{project.phase ? project.phase : '–'}</dd>
        </dl>
    );

    const renderContent = (): JSX.Element => {
        if (statusMessage) {
            return <MessageBar messageBarType={statusMessage.type}>{statusMessage.message}</MessageBar>;
        } else return (
            <>
                {renderProjectSummary()}
                <div>
                    Du er i ferd med å sette dette prosjektet som aktivt. Det blir da tilgjengelig for at brukere kan gjøre endringer igjen. Vil du fortsette?
                </div>
            </>
        );
    };

    const renderFooterButtons = (): JSX.Element | null => {
        if (activating) return null;
        if (statusMessage) return <DefaultButton text='Lukk' onClick={() => close()} />;
        return (
            <div className={styles.footerButtons}>
                <PrimaryButton text='Sett som aktivt' onClick={() => initiateProjectActivation()} />
                <DefaultButton text='Avbryt' onClick={() => close()} />
            </div>
        );
    };

    return (
        <DialogContent className={styles.dialogContent} title='Sett prosjekt som aktivt' showCloseButton={!activating} onDismiss={close} styles={{ inner: { padding: '12px 24px' } }}>
            {activating ? <Spinner label='Aktiverer prosjekt. Vennligst vent. Dette kan ta noen minutter.' size={SpinnerSize.large} /> :
                renderContent()
            }
            <DialogFooter className={styles.dialogFooterContainer}>
                <div className={styles.dialogFooter}>
                    <div className={styles.versionTag}>
                        <span>v{version}</span>
                    </div>
                    {renderFooterButtons()}
                </div>
            </DialogFooter>
        </DialogContent>
    );
};

export default ReactivateProjectDialog;
