import { useState, useEffect } from 'react';
import Head from 'next/head';
import styles from '../styles/ComponentDetail.module.css';

export default function ComponentDetail({ component, logs }) {
  // This page will show the component logs and status
  return (
    <div className={styles.container}>
      <Head>
        <title>{component} Logs</title>
      </Head>
      <h1>{component} Logs</h1>
      <pre className={styles.logs}>
        {logs}
      </pre>
    </div>
  );
}
