<script lang="ts">
  import GrowthChart from '$lib/GrowthChart.svelte';
  import PepeChart from '$lib/PepeChart.svelte';
</script>

<svelte:head>
  <title>Baby Growth Chart</title>
</svelte:head>

<main class="min-h-screen p-6 md:p-10 bg-gradient-to-br from-blue-50 to-purple-50 dark:from-gray-900 dark:to-slate-900">
  <PepeChart />
</main>
